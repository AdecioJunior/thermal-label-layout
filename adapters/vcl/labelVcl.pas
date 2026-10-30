unit labelVcl;

// Delphi VCL / Windows. Este adaptador nao faz parte do build Free Pascal.
interface

uses System.SysUtils, System.Types, Winapi.Windows, Vcl.Graphics, Vcl.Printers,
  labelTypes, labelUtils, labelGeometry, labelPlan;

function lerMetricasImpressora(impressora: TPrinter): TMetricasImpressao;
procedure exportarBitmaps(const layout: TDocumentoLayout; const dados: TRegistrosDados;
  const pastaSaida: string; resolucaoDpi, indiceInicial: Integer);
procedure imprimirLayout(impressora: TPrinter; const layout: TDocumentoLayout;
  const dados: TRegistrosDados; indiceInicial: Integer);

implementation

function lerMetricasImpressora(impressora: TPrinter): TMetricasImpressao;
var contextoDispositivo: HDC;
begin
  if impressora = nil then raise ELabelError.Create('Impressora nao informada.');
  contextoDispositivo := impressora.Handle;
  Result.resolucaoHorizontalDpi := GetDeviceCaps(contextoDispositivo, LOGPIXELSX);
  Result.resolucaoVerticalDpi := GetDeviceCaps(contextoDispositivo, LOGPIXELSY);
  Result.larguraFisicaPixels := GetDeviceCaps(contextoDispositivo, PHYSICALWIDTH);
  Result.alturaFisicaPixels := GetDeviceCaps(contextoDispositivo, PHYSICALHEIGHT);
  Result.larguraImprimivelPixels := GetDeviceCaps(contextoDispositivo, HORZRES);
  Result.alturaImprimivelPixels := GetDeviceCaps(contextoDispositivo, VERTRES);
  Result.deslocamentoHorizontalPixels := GetDeviceCaps(contextoDispositivo, PHYSICALOFFSETX);
  Result.deslocamentoVerticalPixels := GetDeviceCaps(contextoDispositivo, PHYSICALOFFSETY);
  exigirValidade(obterErroMetricas(Result));
end;

procedure configurarFonte(canvasDestino: TCanvas; const texto: TTextoPlanejado;
  resolucaoVerticalDpi: Integer);
begin
  canvasDestino.Font.Name := texto.campo.nomeFonte;
  canvasDestino.Font.Height := -Round(texto.campo.tamanhoFontePt * resolucaoVerticalDpi / 72);
  canvasDestino.Font.Color := clBlack;
  canvasDestino.Font.Style := [];
  if texto.campo.negrito then canvasDestino.Font.Style := [fsBold];
  canvasDestino.Brush.Style := bsClear;
end;

function obterErroTextoNoCanvas(canvasDestino: TCanvas;
  const texto: TTextoPlanejado): string;
begin
  if canvasDestino.TextWidth(texto.texto) > texto.areaPixels.direita - texto.areaPixels.esquerda then
    Exit(texto.campo.nome + ': texto excede a largura do campo no destino.');
  if canvasDestino.TextHeight(texto.texto) > texto.areaPixels.base - texto.areaPixels.topo then
    Exit(texto.campo.nome + ': fonte excede a altura do campo no destino.');
  Result := '';
end;

procedure validarTextos(canvasDestino: TCanvas; const plano: TPlanoImpressao);
var indicePagina, indiceEtiqueta, indiceTexto: Integer; texto: TTextoPlanejado;
begin
  for indicePagina := 0 to High(plano.paginas) do
    for indiceEtiqueta := 0 to High(plano.paginas[indicePagina].etiquetas) do
      for indiceTexto := 0 to High(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos) do
      begin
        texto := plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos[indiceTexto];
        if texto.texto = '' then Continue;
        configurarFonte(canvasDestino, texto, plano.metricas.resolucaoVerticalDpi);
        exigirValidade(obterErroTextoNoCanvas(canvasDestino, texto));
      end;
end;

procedure desenharTexto(canvasDestino: TCanvas; const texto: TTextoPlanejado;
  resolucaoVerticalDpi: Integer);
var areaCampo: TRect; flagsTexto: Cardinal; estadoCanvas: Integer;
begin
  if texto.texto = '' then Exit;
  configurarFonte(canvasDestino, texto, resolucaoVerticalDpi);
  areaCampo := Rect(texto.areaPixels.esquerda, texto.areaPixels.topo,
    texto.areaPixels.direita, texto.areaPixels.base);
  // OR abaixo combina flags de bits da API, nao condicoes de validacao.
  flagsTexto := DT_SINGLELINE or DT_NOPREFIX or DT_TOP;
  if texto.campo.alinhamento = atCentro then flagsTexto := flagsTexto or DT_CENTER;
  if texto.campo.alinhamento = atDireita then flagsTexto := flagsTexto or DT_RIGHT;
  estadoCanvas := SaveDC(canvasDestino.Handle);
  if estadoCanvas = 0 then raise ELabelError.Create('Nao foi possivel preservar o contexto grafico.');
  try
    IntersectClipRect(canvasDestino.Handle, areaCampo.Left, areaCampo.Top, areaCampo.Right, areaCampo.Bottom);
    if DrawText(canvasDestino.Handle, PChar(texto.texto), Length(texto.texto), areaCampo, flagsTexto) = 0 then
      raise ELabelError.Create('Falha ao desenhar o campo ' + texto.campo.nome);
  finally
    RestoreDC(canvasDestino.Handle, estadoCanvas);
  end;
end;

procedure desenharPagina(canvasDestino: TCanvas; const plano: TPlanoImpressao;
  indicePagina: Integer);
var indiceEtiqueta, indiceTexto: Integer;
begin
  for indiceEtiqueta := 0 to High(plano.paginas[indicePagina].etiquetas) do
    for indiceTexto := 0 to High(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos) do
      desenharTexto(canvasDestino,
        plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos[indiceTexto],
        plano.metricas.resolucaoVerticalDpi);
end;

procedure exportarBitmaps(const layout: TDocumentoLayout; const dados: TRegistrosDados;
  const pastaSaida: string; resolucaoDpi, indiceInicial: Integer);
var metricas: TMetricasImpressao; plano: TPlanoImpressao; imagem: TBitmap;
  indicePagina: Integer;
begin
  metricas := criarMetricasSimuladas(layout.configuracao, resolucaoDpi, resolucaoDpi);
  if Int64(metricas.larguraFisicaPixels) * metricas.alturaFisicaPixels > 16000000 then
    raise ELabelError.Create('Previa bitmap excede 16 milhoes de pixels.');
  plano := montarPlano(layout, dados, metricas, indiceInicial);
  imagem := TBitmap.Create;
  try
    imagem.PixelFormat := pf32bit;
    imagem.SetSize(metricas.larguraFisicaPixels, metricas.alturaFisicaPixels);
    validarTextos(imagem.Canvas, plano);
    if not ForceDirectories(pastaSaida) then raise ELabelError.Create('Nao foi possivel criar a pasta de saida.');
    for indicePagina := 0 to High(plano.paginas) do
    begin
      imagem.Canvas.Brush.Style := bsSolid;
      imagem.Canvas.Brush.Color := clWhite;
      imagem.Canvas.FillRect(Rect(0, 0, imagem.Width, imagem.Height));
      desenharPagina(imagem.Canvas, plano, indicePagina);
      imagem.SaveToFile(IncludeTrailingPathDelimiter(pastaSaida) + Format('page-%.3d.bmp', [indicePagina + 1]));
    end;
  finally imagem.Free; end;
end;

procedure imprimirLayout(impressora: TPrinter; const layout: TDocumentoLayout;
  const dados: TRegistrosDados; indiceInicial: Integer);
var plano: TPlanoImpressao; metricas: TMetricasImpressao; indicePagina: Integer;
begin
  if impressora = nil then raise ELabelError.Create('Impressora nao informada.');
  if impressora.Printing then raise ELabelError.Create('A impressora ja tem um documento ativo.');
  impressora.Title := layout.nome;
  impressora.BeginDoc;
  try
    metricas := lerMetricasImpressora(impressora);
    plano := montarPlano(layout, dados, metricas, indiceInicial);
    // Todo o lote e medido no Canvas de destino antes do primeiro desenho.
    validarTextos(impressora.Canvas, plano);
    for indicePagina := 0 to High(plano.paginas) do
    begin
      if indicePagina > 0 then impressora.NewPage;
      desenharPagina(impressora.Canvas, plano, indicePagina);
    end;
    impressora.EndDoc;
  except
    if impressora.Printing then impressora.Abort;
    raise;
  end;
end;

end.
