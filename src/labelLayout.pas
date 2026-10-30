unit labelLayout;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, Classes, IniFiles, labelTypes, labelUtils, labelGeometry;

function carregarLayout(const caminho: string): TDocumentoLayout;
function obterErroCampo(const campo: TCampoLayout;
  const configuracao: TConfiguracaoLayout): string;

implementation

function lerTexto(arquivo: TMemIniFile; const secao, chave: string): string;
begin
  if not arquivo.ValueExists(secao, chave) then
    raise ELabelError.Create(secao + '.' + chave + ': chave obrigatoria ausente.');
  Result := arquivo.ReadString(secao, chave, '');
end;

function lerNumero(arquivo: TMemIniFile; const secao, chave: string): Double;
var texto: string;
begin
  texto := lerTexto(arquivo, secao, chave);
  if not TryStrToFloat(texto, Result, configuracaoInvariante) then
    raise ELabelError.Create(secao + '.' + chave + ': numero invalido; utilize ponto decimal.');
  exigirValidade(obterErroNumeroNaoNegativo(Result, secao + '.' + chave));
end;

function lerInteiro(arquivo: TMemIniFile; const secao, chave: string): Integer;
begin
  if TryStrToInt(lerTexto(arquivo, secao, chave), Result) then Exit;
  raise ELabelError.Create(secao + '.' + chave + ': inteiro invalido.');
end;

function lerBooleano(arquivo: TMemIniFile; const secao, chave: string;
  valorPadrao: Boolean): Boolean;
var texto: string;
begin
  if not arquivo.ValueExists(secao, chave) then Exit(valorPadrao);
  texto := LowerCase(Trim(arquivo.ReadString(secao, chave, '')));
  if texto = 'true' then Exit(True);
  if texto = 'false' then Exit(False);
  raise ELabelError.Create(secao + '.' + chave + ': utilize true ou false.');
end;

procedure validarChaves(arquivo: TMemIniFile; const secao: string;
  const permitidas: array of string);
var chaves: TStringList; indiceChave, indicePermitida: Integer; encontrada: Boolean;
begin
  chaves := TStringList.Create;
  try
    arquivo.ReadSection(secao, chaves);
    for indiceChave := 0 to chaves.Count - 1 do
    begin
      encontrada := False;
      for indicePermitida := Low(permitidas) to High(permitidas) do
      begin
        if not SameText(chaves[indiceChave], permitidas[indicePermitida]) then Continue;
        encontrada := True;
        Break;
      end;
      if encontrada then Continue;
      raise ELabelError.Create(secao + ': chave desconhecida ' + chaves[indiceChave]);
    end;
  finally chaves.Free; end;
end;

function lerOrigem(const texto: string): TOrigemInformacao;
begin
  if texto = 'fixed' then Exit(oiFixa);
  if texto = 'variable' then Exit(oiVariavel);
  raise ELabelError.Create('source: utilize fixed ou variable.');
end;

function lerTipo(const texto: string): TTipoInformacao;
begin
  if texto = 'text' then Exit(tiTexto);
  if texto = 'date' then Exit(tiData);
  if texto = 'decimal' then Exit(tiDecimal);
  if texto = 'integer' then Exit(tiInteiro);
  raise ELabelError.Create('type: utilize text, date, decimal ou integer.');
end;

function lerAlinhamento(const texto: string): TAlinhamentoTexto;
begin
  if texto = 'left' then Exit(atEsquerda);
  if texto = 'center' then Exit(atCentro);
  if texto = 'right' then Exit(atDireita);
  raise ELabelError.Create('align: utilize left, center ou right.');
end;

function obterErroCampo(const campo: TCampoLayout;
  const configuracao: TConfiguracaoLayout): string;
begin
  if campo.nome = '' then Exit('Campo sem nome.');
  Result := obterErroNumeroNaoNegativo(campo.posicaoHorizontalMm, campo.nome + '.xMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(campo.posicaoVerticalMm, campo.nome + '.yMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(campo.larguraMm, campo.nome + '.widthMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(campo.alturaMm, campo.nome + '.heightMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(campo.tamanhoFontePt, campo.nome + '.fontSizePt');
  if Result <> '' then Exit;
  if campo.tamanhoFontePt > 72 then Exit(campo.nome + ': fontSizePt excede 72.');
  if campo.nomeFonte = '' then Exit(campo.nome + ': fontFamily vazio.');
  if campo.posicaoHorizontalMm + campo.larguraMm > configuracao.larguraEtiquetaMm + 1E-9 then
    Exit(campo.nome + ': campo excede a largura da etiqueta.');
  if campo.posicaoVerticalMm + campo.alturaMm > configuracao.alturaEtiquetaMm + 1E-9 then
    Exit(campo.nome + ': campo excede a altura da etiqueta.');
  if campo.origem = oiVariavel then
    if campo.chaveVariavel = '' then Exit(campo.nome + ': bind vazio.');
  Result := '';
end;

function carregarCampo(arquivo: TMemIniFile; const secao: string;
  const configuracao: TConfiguracaoLayout): TCampoLayout;
var larguraTexto: string;
begin
  validarChaves(arquivo, secao, ['source', 'type', 'bind', 'value', 'mask', 'prefix',
    'suffix', 'required', 'xMm', 'yMm', 'widthMm', 'heightMm', 'fontFamily',
    'fontSizePt', 'bold', 'align']);
  Result.nome := Copy(secao, 7, MaxInt);
  Result.origem := lerOrigem(lerTexto(arquivo, secao, 'source'));
  Result.tipoInformacao := lerTipo(lerTexto(arquivo, secao, 'type'));
  Result.chaveVariavel := '';
  Result.valorFixo := '';
  if Result.origem = oiVariavel then
  begin
    Result.chaveVariavel := lerTexto(arquivo, secao, 'bind');
    if arquivo.ValueExists(secao, 'value') then
      raise ELabelError.Create(secao + ': campo variable nao aceita value.');
  end
  else
  begin
    Result.valorFixo := lerTexto(arquivo, secao, 'value');
    if arquivo.ValueExists(secao, 'bind') then
      raise ELabelError.Create(secao + ': campo fixed nao aceita bind.');
  end;
  Result.mascara := arquivo.ReadString(secao, 'mask', '');
  Result.prefixo := arquivo.ReadString(secao, 'prefix', '');
  Result.sufixo := arquivo.ReadString(secao, 'suffix', '');
  Result.obrigatorio := lerBooleano(arquivo, secao, 'required', True);
  Result.posicaoHorizontalMm := lerNumero(arquivo, secao, 'xMm');
  Result.posicaoVerticalMm := lerNumero(arquivo, secao, 'yMm');
  larguraTexto := lerTexto(arquivo, secao, 'widthMm');
  if larguraTexto = 'auto' then
    Result.larguraMm := configuracao.larguraEtiquetaMm - Result.posicaoHorizontalMm - 1
  else
    Result.larguraMm := lerNumero(arquivo, secao, 'widthMm');
  Result.alturaMm := lerNumero(arquivo, secao, 'heightMm');
  Result.nomeFonte := arquivo.ReadString(secao, 'fontFamily', 'Arial');
  Result.tamanhoFontePt := lerNumero(arquivo, secao, 'fontSizePt');
  Result.negrito := lerBooleano(arquivo, secao, 'bold', False);
  Result.alinhamento := lerAlinhamento(arquivo.ReadString(secao, 'align', 'left'));
  exigirValidade(obterErroCampo(Result, configuracao));
end;

function carregarLayout(const caminho: string): TDocumentoLayout;
var arquivo: TMemIniFile; secoes: TStringList; indiceSecao, indiceCampo: Integer;
  secao, separador: string;
begin
  if not FileExists(caminho) then raise ELabelError.Create('Layout nao encontrado: ' + caminho);
  {$IFDEF FPC}
  arquivo := TMemIniFile.Create(caminho);
  {$ELSE}
  arquivo := TMemIniFile.Create(caminho, TEncoding.UTF8);
  {$ENDIF}
  secoes := TStringList.Create;
  try
    validarChaves(arquivo, 'layout', ['version', 'name', 'pageWidthMm', 'pageHeightMm',
      'labelWidthMm', 'labelHeightMm', 'columns', 'columnGapMm', 'rowGapMm',
      'marginLeftMm', 'marginTopMm', 'marginRightMm', 'marginBottomMm']);
    Result.versao := lerInteiro(arquivo, 'layout', 'version');
    if Result.versao <> 1 then raise ELabelError.Create('Versao de layout nao suportada.');
    Result.nome := lerTexto(arquivo, 'layout', 'name');
    Result.configuracao.larguraMidiaMm := lerNumero(arquivo, 'layout', 'pageWidthMm');
    Result.configuracao.alturaPaginaMm := lerNumero(arquivo, 'layout', 'pageHeightMm');
    Result.configuracao.larguraEtiquetaMm := lerNumero(arquivo, 'layout', 'labelWidthMm');
    Result.configuracao.alturaEtiquetaMm := lerNumero(arquivo, 'layout', 'labelHeightMm');
    Result.configuracao.quantidadeColunas := lerInteiro(arquivo, 'layout', 'columns');
    Result.configuracao.espacoEntreColunasMm := lerNumero(arquivo, 'layout', 'columnGapMm');
    Result.configuracao.espacoEntreLinhasMm := lerNumero(arquivo, 'layout', 'rowGapMm');
    Result.configuracao.margemEsquerdaMm := lerNumero(arquivo, 'layout', 'marginLeftMm');
    Result.configuracao.margemSuperiorMm := lerNumero(arquivo, 'layout', 'marginTopMm');
    Result.configuracao.margemDireitaMm := lerNumero(arquivo, 'layout', 'marginRightMm');
    Result.configuracao.margemInferiorMm := lerNumero(arquivo, 'layout', 'marginBottomMm');
    exigirValidade(obterErroConfiguracao(Result.configuracao));
    validarChaves(arquivo, 'format', ['decimalSeparator', 'thousandSeparator']);
    separador := lerTexto(arquivo, 'format', 'decimalSeparator');
    if Length(separador) <> 1 then raise ELabelError.Create('decimalSeparator deve ter 1 caractere ASCII.');
    Result.separadorDecimal := separador[1];
    separador := lerTexto(arquivo, 'format', 'thousandSeparator');
    if Length(separador) <> 1 then raise ELabelError.Create('thousandSeparator deve ter 1 caractere ASCII.');
    Result.separadorMilhar := separador[1];
    if Result.separadorDecimal = Result.separadorMilhar then
      raise ELabelError.Create('Separadores decimal e de milhar devem ser diferentes.');
    arquivo.ReadSections(secoes);
    SetLength(Result.campos, 0);
    for indiceSecao := 0 to secoes.Count - 1 do
    begin
      secao := secoes[indiceSecao];
      if SameText(secao, 'layout') then Continue;
      if SameText(secao, 'format') then Continue;
      if Copy(secao, 1, 6) <> 'field.' then raise ELabelError.Create('Secao desconhecida: ' + secao);
      indiceCampo := Length(Result.campos);
      if indiceCampo >= 64 then raise ELabelError.Create('O layout excede 64 campos.');
      SetLength(Result.campos, indiceCampo + 1);
      Result.campos[indiceCampo] := carregarCampo(arquivo, secao, Result.configuracao);
    end;
    if Length(Result.campos) = 0 then raise ELabelError.Create('O layout deve ter pelo menos um campo.');
  finally
    secoes.Free;
    arquivo.Free;
  end;
end;

end.
