unit labelFormatting;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, labelTypes, labelUtils, labelData;

function tentarLerDataIso(const texto: string; out data: TDateTime): Boolean;
function obterErroDecimalCanonico(const texto: string): string;
function obterErroInteiroCanonico(const texto: string): string;
function formatarCampo(const campo: TCampoLayout; const registro: TRegistroDados;
  const formato: TFormatSettings): string;
function criarFormatoSaida(const layout: TDocumentoLayout): TFormatSettings;

implementation

function criarFormatoSaida(const layout: TDocumentoLayout): TFormatSettings;
begin
  Result := configuracaoInvariante;
  Result.DecimalSeparator := layout.separadorDecimal;
  Result.ThousandSeparator := layout.separadorMilhar;
  Result.DateSeparator := '/';
end;

function tentarLerDataIso(const texto: string; out data: TDateTime): Boolean;
var ano, mes, dia, indiceCaractere: Integer;
begin
  data := 0;
  if Length(texto) <> 10 then Exit(False);
  if texto[5] <> '-' then Exit(False);
  if texto[8] <> '-' then Exit(False);
  for indiceCaractere := 1 to Length(texto) do
  begin
    if indiceCaractere = 5 then Continue;
    if indiceCaractere = 8 then Continue;
    if texto[indiceCaractere] < '0' then Exit(False);
    if texto[indiceCaractere] > '9' then Exit(False);
  end;
  if not TryStrToInt(Copy(texto, 1, 4), ano) then Exit(False);
  if not TryStrToInt(Copy(texto, 6, 2), mes) then Exit(False);
  if not TryStrToInt(Copy(texto, 9, 2), dia) then Exit(False);
  Result := TryEncodeDate(ano, mes, dia, data);
end;

function obterErroDecimalCanonico(const texto: string): string;
var indiceCaractere, inicioNumero, casasDecimais, quantidadeDigitos: Integer;
  encontrouPonto: Boolean; caractere: Char;
begin
  if texto = '' then Exit('Numero vazio.');
  inicioNumero := 1;
  if texto[1] = '-' then inicioNumero := 2;
  if inicioNumero > Length(texto) then Exit('Numero sem digitos.');
  encontrouPonto := False;
  casasDecimais := 0;
  quantidadeDigitos := 0;
  for indiceCaractere := inicioNumero to Length(texto) do
  begin
    caractere := texto[indiceCaractere];
    if caractere = '.' then
    begin
      if encontrouPonto then Exit('Mais de um ponto decimal.');
      if quantidadeDigitos = 0 then Exit('Informe digitos antes do ponto.');
      if indiceCaractere = Length(texto) then Exit('Informe digitos depois do ponto.');
      encontrouPonto := True;
      Continue;
    end;
    if caractere < '0' then Exit('Numero deve usar digitos e ponto decimal, sem agrupamento.');
    if caractere > '9' then Exit('Numero deve usar digitos e ponto decimal, sem agrupamento.');
    Inc(quantidadeDigitos);
    if not encontrouPonto then Continue;
    Inc(casasDecimais);
    if casasDecimais > 4 then Exit('Decimal suporta no maximo 4 casas, sem arredondar a entrada.');
  end;
  Result := '';
end;

function obterErroInteiroCanonico(const texto: string): string;
var indiceCaractere, inicioNumero: Integer;
begin
  if texto = '' then Exit('Inteiro vazio.');
  inicioNumero := 1;
  if texto[1] = '-' then inicioNumero := 2;
  if inicioNumero > Length(texto) then Exit('Inteiro sem digitos.');
  for indiceCaractere := inicioNumero to Length(texto) do
  begin
    if texto[indiceCaractere] < '0' then Exit('Inteiro deve usar somente digitos e sinal negativo opcional.');
    if texto[indiceCaractere] > '9' then Exit('Inteiro deve usar somente digitos e sinal negativo opcional.');
  end;
  Result := '';
end;

function aplicarMascaraTexto(const valor, mascara: string): string;
var posicaoValor: Integer; restante: string;
begin
  if mascara = '' then Exit(valor);
  posicaoValor := Pos('{value}', mascara);
  if posicaoValor = 0 then raise ELabelError.Create('Mascara de texto exige um {value}.');
  restante := Copy(mascara, posicaoValor + 7, MaxInt);
  if Pos('{value}', restante) > 0 then raise ELabelError.Create('Mascara de texto aceita apenas um {value}.');
  Result := Copy(mascara, 1, posicaoValor - 1) + valor + restante;
end;

function formatarValorTipado(const campo: TCampoLayout; const valor: string;
  const formato: TFormatSettings): string;
var data: TDateTime; valorDecimal: Currency; valorInteiro: Int64; mascara: string;
begin
  if campo.tipoInformacao = tiTexto then Exit(aplicarMascaraTexto(valor, campo.mascara));
  if campo.tipoInformacao = tiData then
  begin
    if not tentarLerDataIso(valor, data) then
      raise ELabelError.Create(campo.nome + ': data invalida; utilize YYYY-MM-DD.');
    mascara := campo.mascara;
    if mascara = '' then mascara := 'dd/mm/yyyy';
    Exit(FormatDateTime(mascara, data, formato));
  end;
  if campo.tipoInformacao = tiDecimal then
  begin
    exigirValidade(obterErroDecimalCanonico(valor));
    if not TryStrToCurr(valor, valorDecimal, configuracaoInvariante) then
      raise ELabelError.Create(campo.nome + ': decimal fora do intervalo de Currency.');
    mascara := campo.mascara;
    if mascara = '' then mascara := '0.00';
    Exit(FormatCurr(mascara, valorDecimal, formato));
  end;
  exigirValidade(obterErroInteiroCanonico(valor));
  if not TryStrToInt64(valor, valorInteiro) then
    raise ELabelError.Create(campo.nome + ': inteiro invalido.');
  if campo.mascara = '' then Exit(IntToStr(valorInteiro));
  // Mascara de inteiro e somente preenchimento com zeros. Nao converte para float.
  mascara := StringOfChar('0', Length(campo.mascara));
  if campo.mascara <> mascara then raise ELabelError.Create('Mascara de inteiro aceita apenas zeros.');
  Result := IntToStr(valorInteiro);
  if valorInteiro < 0 then Delete(Result, 1, 1);
  if Length(Result) < Length(mascara) then
    Result := StringOfChar('0', Length(mascara) - Length(Result)) + Result;
  if valorInteiro < 0 then Result := '-' + Result;
end;

function formatarCampo(const campo: TCampoLayout; const registro: TRegistroDados;
  const formato: TFormatSettings): string;
var valor: string; encontrado: Boolean;
begin
  valor := campo.valorFixo;
  if campo.origem = oiVariavel then
  begin
    encontrado := buscarValor(registro, campo.chaveVariavel, valor);
    if not encontrado then
    begin
      if not campo.obrigatorio then Exit('');
      raise ELabelError.Create(campo.nome + ': variavel ausente: ' + campo.chaveVariavel);
    end;
  end;
  if valor = '' then
  begin
    if not campo.obrigatorio then Exit('');
    raise ELabelError.Create(campo.nome + ': valor obrigatorio vazio.');
  end;
  Result := campo.prefixo + formatarValorTipado(campo, valor, formato) + campo.sufixo;
end;

end.
