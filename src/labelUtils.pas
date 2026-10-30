unit labelUtils;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, Classes, Math, labelTypes;

function configuracaoInvariante: TFormatSettings;
function obterErroNumeroPositivo(valor: Double; const nome: string): string;
function obterErroNumeroNaoNegativo(valor: Double; const nome: string): string;
procedure exigirValidade(const erro: string);
function milimetrosParaPixels(medidaMm: Double; resolucaoDpi: Integer): Integer;
function numeroSvg(valor: Double): string;
function escaparXml(const texto: string): string;
procedure salvarTextoUtf8(const caminho, texto: string);
function carregarLinhasUtf8(const caminho: string): TStringList;

implementation

function configuracaoInvariante: TFormatSettings;
begin
  {$IFDEF FPC}
  Result := DefaultFormatSettings;
  {$ELSE}
  Result := TFormatSettings.Create;
  {$ENDIF}
  Result.DecimalSeparator := '.';
  Result.ThousandSeparator := ',';
  Result.DateSeparator := '/';
  Result.TimeSeparator := ':';
end;

function obterErroNumeroNaoNegativo(valor: Double; const nome: string): string;
begin
  if IsNan(valor) then Exit(nome + ': NaN nao e permitido.');
  if IsInfinite(valor) then Exit(nome + ': infinito nao e permitido.');
  if valor < 0 then Exit(nome + ': deve ser maior ou igual a zero.');
  if valor > 10000 then Exit(nome + ': excede o limite de 10000.');
  Result := '';
end;

function obterErroNumeroPositivo(valor: Double; const nome: string): string;
begin
  Result := obterErroNumeroNaoNegativo(valor, nome);
  if Result <> '' then Exit;
  if valor = 0 then Exit(nome + ': deve ser maior que zero.');
end;

procedure exigirValidade(const erro: string);
begin
  if erro = '' then Exit;
  raise ELabelError.Create(erro);
end;

function milimetrosParaPixels(medidaMm: Double; resolucaoDpi: Integer): Integer;
begin
  Result := Round(medidaMm * resolucaoDpi / 25.4);
end;

function numeroSvg(valor: Double): string;
begin
  Result := FormatFloat('0.######', valor, configuracaoInvariante);
end;

function escaparXml(const texto: string): string;
begin
  Result := StringReplace(texto, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

procedure salvarTextoUtf8(const caminho, texto: string);
var
  arquivo: TFileStream;
  conteudoUtf8: UTF8String;
begin
  {$IFDEF FPC}
  conteudoUtf8 := UTF8String(texto);
  {$ELSE}
  conteudoUtf8 := UTF8Encode(texto);
  {$ENDIF}
  arquivo := TFileStream.Create(caminho, fmCreate);
  try
    if Length(conteudoUtf8) = 0 then Exit;
    arquivo.WriteBuffer(conteudoUtf8[1], Length(conteudoUtf8));
  finally
    arquivo.Free;
  end;
end;

function carregarLinhasUtf8(const caminho: string): TStringList;
begin
  if not FileExists(caminho) then
    raise ELabelError.Create('Arquivo nao encontrado: ' + caminho);
  Result := TStringList.Create;
  try
    {$IFDEF FPC}
    Result.LoadFromFile(caminho);
    {$ELSE}
    Result.LoadFromFile(caminho, TEncoding.UTF8);
    {$ENDIF}
  except
    Result.Free;
    raise;
  end;
end;

end.
