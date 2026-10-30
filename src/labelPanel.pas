unit labelPanel;

{$mode delphi}{$H+}{$codepage utf8}

interface

procedure iniciarPainel(porta: Integer; abrirNavegador: Boolean);

implementation

uses SysUtils, Classes, fphttpserver, fpjson, jsonparser, Process,
  {$IFDEF MSWINDOWS}Windows, ShellApi,{$ENDIF}
  labelTypes, labelUtils, labelLayout, labelData, labelGeometry, labelPlan, labelSvg;

type
  TServidorPainel = class(TFPHTTPServer)
  private
    pastaProjeto, pastaLote, identificadorSessao: string;
    navegadorPendente: Boolean;
    procedure aoFicarOcioso(remetente: TObject);
    procedure responderJson(resposta: TFPHTTPConnectionResponse; documento: TJSONData);
    procedure responderArquivo(resposta: TFPHTTPConnectionResponse;
      const caminhoRelativo, tipoConteudo: string);
    procedure responderConfiguracao(resposta: TFPHTTPConnectionResponse);
    procedure responderPrevia(requisicao: TFPHTTPConnectionRequest;
      resposta: TFPHTTPConnectionResponse);
  protected
    procedure HandleRequest(var requisicao: TFPHTTPConnectionRequest;
      var resposta: TFPHTTPConnectionResponse); override;
  public
    constructor Create(const raiz: string; portaServidor: Integer; abrirNavegador: Boolean); reintroduce;
  end;

function lerTextoArquivo(const caminho: string): string;
var linhas: TStringList;
begin
  linhas := carregarLinhasUtf8(caminho);
  try Result := linhas.Text; finally linhas.Free; end;
end;

function localizarProjeto: string;
var pastaExecutavel: string;
begin
  Result := IncludeTrailingPathDelimiter(GetCurrentDir);
  if FileExists(Result + 'web/index.html') then Exit;
  pastaExecutavel := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(0))));
  Result := pastaExecutavel;
  if FileExists(Result + 'web/index.html') then Exit;
  Result := IncludeTrailingPathDelimiter(ExpandFileName(pastaExecutavel + '..'));
  if FileExists(Result + 'web/index.html') then Exit;
  raise ELabelError.Create('Pasta web nao encontrada. Execute a partir da raiz do projeto.');
end;

constructor TServidorPainel.Create(const raiz: string; portaServidor: Integer; abrirNavegador: Boolean);
var identificador: TGUID;
begin
  inherited Create(nil);
  pastaProjeto := IncludeTrailingPathDelimiter(raiz);
  pastaLote := pastaProjeto + 'output/panel/' + IntToStr(portaServidor) + '/';
  if not ForceDirectories(pastaLote) then raise ELabelError.Create('Nao foi possivel criar a pasta do painel.');
  if CreateGUID(identificador) <> 0 then raise ELabelError.Create('Nao foi possivel iniciar a sessao do painel.');
  identificadorSessao := GUIDToString(identificador);
  Address := '127.0.0.1';
  Port := portaServidor;
  Threaded := False;
  AcceptIdleTimeout := 150;
  OnAcceptIdle := aoFicarOcioso;
  navegadorPendente := abrirNavegador;
end;

procedure TServidorPainel.aoFicarOcioso(remetente: TObject);
var endereco: string;
  {$IFNDEF MSWINDOWS}processoNavegador: TProcess;{$ENDIF}
begin
  if not navegadorPendente then Exit;
  navegadorPendente := False;
  endereco := 'http://127.0.0.1:' + IntToStr(Port) + '/';
  {$IFDEF MSWINDOWS}
  if ShellExecuteW(0, 'open', PWideChar(UTF8Decode(endereco)), nil, nil, SW_SHOWNORMAL) <= 32 then
    WriteLn('Abra no navegador: ', endereco);
  {$ELSE}
  processoNavegador := TProcess.Create(nil);
  try
    {$IFDEF DARWIN}processoNavegador.Executable := 'open';
    {$ELSE}processoNavegador.Executable := 'xdg-open';{$ENDIF}
    processoNavegador.Parameters.Add(endereco);
    try processoNavegador.Execute;
    except on erro: Exception do WriteLn('Abra no navegador: ', endereco); end;
  finally processoNavegador.Free; end;
  {$ENDIF}
end;

procedure TServidorPainel.responderJson(resposta: TFPHTTPConnectionResponse; documento: TJSONData);
begin
  try
    resposta.ContentType := 'application/json; charset=utf-8';
    resposta.Content := documento.AsJSON;
  finally documento.Free; end;
end;

procedure TServidorPainel.responderArquivo(resposta: TFPHTTPConnectionResponse;
  const caminhoRelativo, tipoConteudo: string);
begin
  resposta.ContentType := tipoConteudo + '; charset=utf-8';
  resposta.Content := lerTextoArquivo(pastaProjeto + caminhoRelativo);
end;

procedure TServidorPainel.responderConfiguracao(resposta: TFPHTTPConnectionResponse);
var documento, modelos: TJSONObject;
begin
  documento := TJSONObject.Create;
  try
    documento.Add('session', identificadorSessao);
    documento.Add('data', lerTextoArquivo(pastaProjeto + 'examples/sample-data.ini'));
    modelos := TJSONObject.Create;
    documento.Add('presets', modelos);
    modelos.Add('3', lerTextoArquivo(pastaProjeto + 'examples/labels-3.lay'));
    modelos.Add('5', lerTextoArquivo(pastaProjeto + 'examples/labels-5.lay'));
    modelos.Add('6', lerTextoArquivo(pastaProjeto + 'examples/labels-6.lay'));
  except documento.Free; raise; end;
  responderJson(resposta, documento);
end;

function exigirTextoJson(documento: TJSONObject; const chave: string): string;
var valor: TJSONData;
begin
  valor := documento.Find(chave);
  if valor = nil then raise ELabelError.Create('Parametro ausente: ' + chave);
  if valor.JSONType <> jtString then raise ELabelError.Create('Parametro deve ser texto: ' + chave);
  Result := valor.AsString;
end;

function exigirInteiroJson(documento: TJSONObject; const chave: string): Integer;
var valor: TJSONData;
begin
  valor := documento.Find(chave);
  if valor = nil then raise ELabelError.Create('Parametro ausente: ' + chave);
  if valor.JSONType <> jtNumber then raise ELabelError.Create('Parametro deve ser numero: ' + chave);
  if not TryStrToInt(valor.AsString, Result) then raise ELabelError.Create('Parametro deve ser inteiro: ' + chave);
end;

procedure TServidorPainel.responderPrevia(requisicao: TFPHTTPConnectionRequest;
  resposta: TFPHTTPConnectionResponse);
var documentoRecebido: TJSONData; entrada, documento: TJSONObject;
  layout: TDocumentoLayout; dados: TRegistrosDados; metricas: TMetricasImpressao;
  plano: TPlanoImpressao; grade: TGradeEtiquetas; paginas: TJSONArray;
  resolucaoDpi, indiceInicial, indicePagina: Integer;
begin
  if requisicao.GetCustomHeader('X-Label-Session') <> identificadorSessao then
  begin
    resposta.Code := 403;
    responderJson(resposta, TJSONObject.Create(['error', 'Sessao invalida. Recarregue o painel.']));
    Exit;
  end;
  if Length(requisicao.Content) > 262144 then raise ELabelError.Create('Entrada excede 256 KiB.');
  if Pos('application/json', LowerCase(requisicao.ContentType)) <> 1 then
    raise ELabelError.Create('Envie application/json.');
  documentoRecebido := GetJSON(requisicao.Content);
  try
    if documentoRecebido.JSONType <> jtObject then raise ELabelError.Create('Requisicao deve ser um objeto JSON.');
    entrada := TJSONObject(documentoRecebido);
    resolucaoDpi := exigirInteiroJson(entrada, 'dpi');
    if resolucaoDpi < 72 then raise ELabelError.Create('O painel aceita DPI entre 72 e 600.');
    if resolucaoDpi > 600 then raise ELabelError.Create('O painel aceita DPI entre 72 e 600.');
    indiceInicial := exigirInteiroJson(entrada, 'startIndex');
    salvarTextoUtf8(pastaLote + 'current.lay', exigirTextoJson(entrada, 'layout'));
    salvarTextoUtf8(pastaLote + 'data.ini', exigirTextoJson(entrada, 'data'));
    layout := carregarLayout(pastaLote + 'current.lay');
    dados := carregarDados(pastaLote + 'data.ini');
    if Length(dados) > 200 then raise ELabelError.Create('O painel aceita ate 200 registros por previa.');
    if layout.configuracao.larguraMidiaMm > 500 then raise ELabelError.Create('Pagina do painel limitada a 500 mm.');
    if layout.configuracao.alturaPaginaMm > 500 then raise ELabelError.Create('Pagina do painel limitada a 500 mm.');
    metricas := criarMetricasSimuladas(layout.configuracao, resolucaoDpi, resolucaoDpi);
    grade := calcularGrade(layout.configuracao, metricas);
    if indiceInicial < 0 then raise ELabelError.Create('O indice inicial nao pode ser negativo.');
    if indiceInicial >= grade.etiquetasPorPagina then
      raise ELabelError.Create('O indice inicial deve pertencer a primeira pagina.');
    if (indiceInicial + Length(dados) - 1) div grade.etiquetasPorPagina >= 50 then
      raise ELabelError.Create('O painel aceita ate 50 paginas por previa.');
    plano := montarPlano(layout, dados, metricas, indiceInicial);
    exportarPrevia(plano, pastaLote + 'preview');
    documento := TJSONObject.Create;
    try
      documento.Add('records', Length(dados));
      documento.Add('rows', grade.quantidadeLinhas);
      documento.Add('capacity', grade.etiquetasPorPagina);
      documento.Add('pageWidthMm', layout.configuracao.larguraMidiaMm);
      documento.Add('pageHeightMm', layout.configuracao.alturaPaginaMm);
      paginas := TJSONArray.Create;
      documento.Add('pages', paginas);
      for indicePagina := 0 to High(plano.paginas) do paginas.Add(renderizarPaginaSvg(plano, indicePagina));
    except documento.Free; raise; end;
    responderJson(resposta, documento);
  finally documentoRecebido.Free; end;
end;

procedure TServidorPainel.HandleRequest(var requisicao: TFPHTTPConnectionRequest;
  var resposta: TFPHTTPConnectionResponse);
begin
  resposta.CustomHeaders.Values['Cache-Control'] := 'no-store';
  resposta.CustomHeaders.Values['X-Content-Type-Options'] := 'nosniff';
  resposta.CustomHeaders.Values['Referrer-Policy'] := 'no-referrer';
  resposta.CustomHeaders.Values['Content-Security-Policy'] :=
    'default-src ''self''; script-src ''self''; style-src ''self'' ''unsafe-inline''; ' +
    'img-src ''self'' blob: data:; connect-src ''self''; frame-ancestors ''none''; object-src ''none''';
  try
    if requisicao.Host <> '127.0.0.1:' + IntToStr(Port) then
    begin
      resposta.Code := 403;
      responderJson(resposta, TJSONObject.Create(['error', 'Host invalido. Use 127.0.0.1.']));
      Exit;
    end;
    if requisicao.Method = 'GET' then
    begin
      if requisicao.URI = '/' then begin responderArquivo(resposta, 'web/index.html', 'text/html'); Exit; end;
      if requisicao.URI = '/panel.css' then begin responderArquivo(resposta, 'web/panel.css', 'text/css'); Exit; end;
      if requisicao.URI = '/panel.js' then begin responderArquivo(resposta, 'web/panel.js', 'text/javascript'); Exit; end;
      if requisicao.URI = '/api/config' then begin responderConfiguracao(resposta); Exit; end;
    end;
    if requisicao.Method = 'POST' then
      if requisicao.URI = '/api/preview' then begin responderPrevia(requisicao, resposta); Exit; end;
    resposta.Code := 404;
    responderJson(resposta, TJSONObject.Create(['error', 'Recurso nao encontrado.']));
  except
    on erro: Exception do
    begin
      resposta.Code := 400;
      responderJson(resposta, TJSONObject.Create(['error', erro.Message]));
    end;
  end;
end;

procedure iniciarPainel(porta: Integer; abrirNavegador: Boolean);
var servidor: TServidorPainel;
begin
  if porta < 1024 then raise ELabelError.Create('Porta deve estar entre 1024 e 65535.');
  if porta > 65535 then raise ELabelError.Create('Porta deve estar entre 1024 e 65535.');
  servidor := TServidorPainel.Create(localizarProjeto, porta, abrirNavegador);
  try
    WriteLn('Painel: http://127.0.0.1:', porta, '/');
    WriteLn('Mantenha o programa em execucao. Para encerrar, pare pela IDE ou use Ctrl+C.');
    servidor.Active := True;
  finally servidor.Free; end;
end;

end.
