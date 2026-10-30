unit labelGeometry;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, Math, labelTypes, labelUtils;

function obterErroConfiguracao(const configuracao: TConfiguracaoLayout): string;
function obterErroMetricas(const metricas: TMetricasImpressao): string;
function criarMetricasSimuladas(const configuracao: TConfiguracaoLayout;
  resolucaoHorizontalDpi, resolucaoVerticalDpi: Integer): TMetricasImpressao;
function calcularGrade(const configuracao: TConfiguracaoLayout;
  const metricas: TMetricasImpressao): TGradeEtiquetas;
function calcularAreaEtiqueta(const configuracao: TConfiguracaoLayout;
  indiceNaPagina: Integer): TAreaMilimetros;
function converterAreaParaPixels(const areaMm: TAreaMilimetros;
  const metricas: TMetricasImpressao): TAreaPixels;
function obterErroAreaImprimivel(const area: TAreaPixels;
  const metricas: TMetricasImpressao): string;

implementation

function obterErroConfiguracao(const configuracao: TConfiguracaoLayout): string;
begin
  Result := obterErroNumeroPositivo(configuracao.larguraMidiaMm, 'pageWidthMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(configuracao.alturaPaginaMm, 'pageHeightMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(configuracao.larguraEtiquetaMm, 'labelWidthMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroPositivo(configuracao.alturaEtiquetaMm, 'labelHeightMm');
  if Result <> '' then Exit;
  if configuracao.quantidadeColunas < 1 then Exit('columns: deve ser pelo menos 1.');
  if configuracao.quantidadeColunas > 1000 then Exit('columns: excede 1000.');
  Result := obterErroNumeroNaoNegativo(configuracao.espacoEntreColunasMm, 'columnGapMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(configuracao.espacoEntreLinhasMm, 'rowGapMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(configuracao.margemEsquerdaMm, 'marginLeftMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(configuracao.margemDireitaMm, 'marginRightMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(configuracao.margemSuperiorMm, 'marginTopMm');
  if Result <> '' then Exit;
  Result := obterErroNumeroNaoNegativo(configuracao.margemInferiorMm, 'marginBottomMm');
end;

function obterErroMetricas(const metricas: TMetricasImpressao): string;
begin
  if metricas.resolucaoHorizontalDpi <= 0 then Exit('Resolucao horizontal invalida.');
  if metricas.resolucaoVerticalDpi <= 0 then Exit('Resolucao vertical invalida.');
  if metricas.resolucaoHorizontalDpi > 9600 then Exit('Resolucao horizontal excede 9600 DPI.');
  if metricas.resolucaoVerticalDpi > 9600 then Exit('Resolucao vertical excede 9600 DPI.');
  if metricas.larguraFisicaPixels <= 0 then Exit('Largura fisica invalida.');
  if metricas.alturaFisicaPixels <= 0 then Exit('Altura fisica invalida.');
  if metricas.larguraImprimivelPixels <= 0 then Exit('Largura imprimivel invalida.');
  if metricas.alturaImprimivelPixels <= 0 then Exit('Altura imprimivel invalida.');
  if metricas.deslocamentoHorizontalPixels < 0 then Exit('Deslocamento horizontal negativo.');
  if metricas.deslocamentoVerticalPixels < 0 then Exit('Deslocamento vertical negativo.');
  if metricas.deslocamentoHorizontalPixels + metricas.larguraImprimivelPixels >
     metricas.larguraFisicaPixels then Exit('Area imprimivel excede a largura fisica.');
  if metricas.deslocamentoVerticalPixels + metricas.alturaImprimivelPixels >
     metricas.alturaFisicaPixels then Exit('Area imprimivel excede a altura fisica.');
  Result := '';
end;

function criarMetricasSimuladas(const configuracao: TConfiguracaoLayout;
  resolucaoHorizontalDpi, resolucaoVerticalDpi: Integer): TMetricasImpressao;
begin
  exigirValidade(obterErroConfiguracao(configuracao));
  if resolucaoHorizontalDpi <= 0 then raise ELabelError.Create('DPI horizontal invalido.');
  if resolucaoVerticalDpi <= 0 then raise ELabelError.Create('DPI vertical invalido.');
  if resolucaoHorizontalDpi > 9600 then raise ELabelError.Create('DPI horizontal excede 9600.');
  if resolucaoVerticalDpi > 9600 then raise ELabelError.Create('DPI vertical excede 9600.');
  Result.resolucaoHorizontalDpi := resolucaoHorizontalDpi;
  Result.resolucaoVerticalDpi := resolucaoVerticalDpi;
  Result.larguraFisicaPixels := milimetrosParaPixels(configuracao.larguraMidiaMm, resolucaoHorizontalDpi);
  Result.alturaFisicaPixels := milimetrosParaPixels(configuracao.alturaPaginaMm, resolucaoVerticalDpi);
  Result.larguraImprimivelPixels := Result.larguraFisicaPixels;
  Result.alturaImprimivelPixels := Result.alturaFisicaPixels;
  Result.deslocamentoHorizontalPixels := 0;
  Result.deslocamentoVerticalPixels := 0;
  exigirValidade(obterErroMetricas(Result));
end;

function calcularAreaEtiqueta(const configuracao: TConfiguracaoLayout;
  indiceNaPagina: Integer): TAreaMilimetros;
var
  indiceColuna, indiceLinha: Integer;
begin
  exigirValidade(obterErroConfiguracao(configuracao));
  if indiceNaPagina < 0 then raise ELabelError.Create('Indice de etiqueta negativo.');
  indiceColuna := indiceNaPagina mod configuracao.quantidadeColunas;
  indiceLinha := indiceNaPagina div configuracao.quantidadeColunas;
  Result.esquerdaMm := configuracao.margemEsquerdaMm + indiceColuna *
    (configuracao.larguraEtiquetaMm + configuracao.espacoEntreColunasMm);
  Result.topoMm := configuracao.margemSuperiorMm + indiceLinha *
    (configuracao.alturaEtiquetaMm + configuracao.espacoEntreLinhasMm);
  Result.direitaMm := Result.esquerdaMm + configuracao.larguraEtiquetaMm;
  Result.baseMm := Result.topoMm + configuracao.alturaEtiquetaMm;
end;

function converterAreaParaPixels(const areaMm: TAreaMilimetros;
  const metricas: TMetricasImpressao): TAreaPixels;
begin
  // Cada borda parte da medida fisica, sem acumular passos arredondados.
  Result.esquerda := milimetrosParaPixels(areaMm.esquerdaMm, metricas.resolucaoHorizontalDpi) -
    metricas.deslocamentoHorizontalPixels;
  Result.direita := milimetrosParaPixels(areaMm.direitaMm, metricas.resolucaoHorizontalDpi) -
    metricas.deslocamentoHorizontalPixels;
  Result.topo := milimetrosParaPixels(areaMm.topoMm, metricas.resolucaoVerticalDpi) -
    metricas.deslocamentoVerticalPixels;
  Result.base := milimetrosParaPixels(areaMm.baseMm, metricas.resolucaoVerticalDpi) -
    metricas.deslocamentoVerticalPixels;
end;

function obterErroAreaImprimivel(const area: TAreaPixels;
  const metricas: TMetricasImpressao): string;
begin
  if area.esquerda < 0 then Exit('Area invade a margem fisica esquerda do dispositivo.');
  if area.topo < 0 then Exit('Area invade a margem fisica superior do dispositivo.');
  if area.direita > metricas.larguraImprimivelPixels then Exit('Area excede a largura imprimivel.');
  if area.base > metricas.alturaImprimivelPixels then Exit('Area excede a altura imprimivel.');
  if area.direita <= area.esquerda then Exit('Area nao tem largura em pixels.');
  if area.base <= area.topo then Exit('Area nao tem altura em pixels.');
  Result := '';
end;

function calcularGrade(const configuracao: TConfiguracaoLayout;
  const metricas: TMetricasImpressao): TGradeEtiquetas;
var
  larguraNecessariaMm, alturaDisponivelMm: Double;
  primeiraAreaMm, ultimaAreaMm: TAreaMilimetros;
begin
  exigirValidade(obterErroConfiguracao(configuracao));
  exigirValidade(obterErroMetricas(metricas));
  if Abs(milimetrosParaPixels(configuracao.larguraMidiaMm,
    metricas.resolucaoHorizontalDpi) - metricas.larguraFisicaPixels) > 1 then
    raise ELabelError.Create('A largura fisica do dispositivo diverge da midia do layout.');
  if Abs(milimetrosParaPixels(configuracao.alturaPaginaMm,
    metricas.resolucaoVerticalDpi) - metricas.alturaFisicaPixels) > 1 then
    raise ELabelError.Create('A altura fisica do dispositivo diverge da pagina do layout.');

  larguraNecessariaMm := configuracao.margemEsquerdaMm +
    configuracao.quantidadeColunas * configuracao.larguraEtiquetaMm +
    (configuracao.quantidadeColunas - 1) * configuracao.espacoEntreColunasMm +
    configuracao.margemDireitaMm;
  if larguraNecessariaMm > configuracao.larguraMidiaMm + 1E-9 then
    raise ELabelError.Create('As colunas e margens excedem a largura da midia.');
  alturaDisponivelMm := configuracao.alturaPaginaMm -
    configuracao.margemSuperiorMm - configuracao.margemInferiorMm;
  Result.quantidadeLinhas := Floor((alturaDisponivelMm + configuracao.espacoEntreLinhasMm) /
    (configuracao.alturaEtiquetaMm + configuracao.espacoEntreLinhasMm) + 1E-9);
  if Result.quantidadeLinhas < 1 then raise ELabelError.Create('Nenhuma linha cabe na pagina.');
  if Result.quantidadeLinhas > 10000 then raise ELabelError.Create('A grade excede 10000 linhas.');
  Result.etiquetasPorPagina := Result.quantidadeLinhas * configuracao.quantidadeColunas;
  primeiraAreaMm := calcularAreaEtiqueta(configuracao, 0);
  ultimaAreaMm := calcularAreaEtiqueta(configuracao, Result.etiquetasPorPagina - 1);
  exigirValidade(obterErroAreaImprimivel(converterAreaParaPixels(primeiraAreaMm, metricas), metricas));
  exigirValidade(obterErroAreaImprimivel(converterAreaParaPixels(ultimaAreaMm, metricas), metricas));
end;

end.
