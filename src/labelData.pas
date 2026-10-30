unit labelData;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, Classes, IniFiles, labelTypes;

function carregarDados(const caminho: string): TRegistrosDados;
function buscarValor(const registro: TRegistroDados; const chave: string;
  out valor: string): Boolean;

implementation

function buscarValor(const registro: TRegistroDados; const chave: string;
  out valor: string): Boolean;
var indiceValor: Integer;
begin
  valor := '';
  for indiceValor := 0 to High(registro.valores) do
  begin
    if registro.valores[indiceValor].nome <> chave then Continue;
    valor := registro.valores[indiceValor].valor;
    Exit(True);
  end;
  Result := False;
end;

function carregarDados(const caminho: string): TRegistrosDados;
var arquivo: TMemIniFile; chaves: TStringList;
  quantidadeRegistros, indiceRegistro, indiceChave: Integer; secao: string;
begin
  Result := nil;
  if not FileExists(caminho) then raise ELabelError.Create('Dados nao encontrados: ' + caminho);
  {$IFDEF FPC}
  arquivo := TMemIniFile.Create(caminho);
  {$ELSE}
  arquivo := TMemIniFile.Create(caminho, TEncoding.UTF8);
  {$ENDIF}
  chaves := TStringList.Create;
  try
    if not TryStrToInt(arquivo.ReadString('batch', 'count', ''), quantidadeRegistros) then
      raise ELabelError.Create('batch.count: inteiro obrigatorio.');
    if quantidadeRegistros < 1 then raise ELabelError.Create('O lote nao pode estar vazio.');
    if quantidadeRegistros > 10000 then raise ELabelError.Create('O lote excede 10000 registros.');
    SetLength(Result, quantidadeRegistros);
    for indiceRegistro := 0 to quantidadeRegistros - 1 do
    begin
      secao := 'record.' + IntToStr(indiceRegistro);
      if not arquivo.SectionExists(secao) then raise ELabelError.Create('Secao ausente: ' + secao);
      chaves.Clear;
      arquivo.ReadSection(secao, chaves);
      SetLength(Result[indiceRegistro].valores, chaves.Count);
      for indiceChave := 0 to chaves.Count - 1 do
      begin
        Result[indiceRegistro].valores[indiceChave].nome := chaves[indiceChave];
        Result[indiceRegistro].valores[indiceChave].valor := arquivo.ReadString(secao, chaves[indiceChave], '');
      end;
    end;
  finally
    chaves.Free;
    arquivo.Free;
  end;
end;

end.
