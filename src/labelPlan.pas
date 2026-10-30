unit labelPlan;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, labelTypes, labelUtils, labelGeometry, labelLayout, labelFormatting;

function montarPlano(const layout: TDocumentoLayout; const dados: TRegistrosDados;
  const metricas: TMetricasImpressao; indiceInicial: Integer): TPlanoImpressao;

implementation

function calcularAreaCampo(const etiquetaMm: TAreaMilimetros;
  const campo: TCampoLayout): TAreaMilimetros;
begin
  Result.esquerdaMm := etiquetaMm.esquerdaMm + campo.posicaoHorizontalMm;
  Result.topoMm := etiquetaMm.topoMm + campo.posicaoVerticalMm;
  Result.direitaMm := Result.esquerdaMm + campo.larguraMm;
  Result.baseMm := Result.topoMm + campo.alturaMm;
end;

function montarPlano(const layout: TDocumentoLayout; const dados: TRegistrosDados;
  const metricas: TMetricasImpressao; indiceInicial: Integer): TPlanoImpressao;
var grade: TGradeEtiquetas; formato: TFormatSettings;
  indiceRegistro, indiceCampo, indicePagina, indiceNaPagina: Integer;
  indiceNoVetor, quantidadePaginas, posicaoAbsoluta: Integer;
  etiquetaMm: TAreaMilimetros; etiqueta: TEtiquetaPlanejada;
begin
  grade := calcularGrade(layout.configuracao, metricas);
  if Length(dados) = 0 then raise ELabelError.Create('Nao ha registros para imprimir.');
  if Length(dados) > 10000 then raise ELabelError.Create('O lote excede 10000 registros.');
  if Length(layout.campos) = 0 then raise ELabelError.Create('Layout sem campos.');
  if indiceInicial < 0 then raise ELabelError.Create('O indice inicial nao pode ser negativo.');
  if indiceInicial >= grade.etiquetasPorPagina then
    raise ELabelError.Create('O indice inicial deve pertencer a primeira pagina.');
  for indiceCampo := 0 to High(layout.campos) do
    exigirValidade(obterErroCampo(layout.campos[indiceCampo], layout.configuracao));
  quantidadePaginas := ((indiceInicial + Length(dados) - 1) div grade.etiquetasPorPagina) + 1;
  Result.nome := layout.nome;
  Result.metricas := metricas;
  SetLength(Result.paginas, quantidadePaginas);
  formato := criarFormatoSaida(layout);
  for indiceRegistro := 0 to High(dados) do
  begin
    posicaoAbsoluta := indiceInicial + indiceRegistro;
    indicePagina := posicaoAbsoluta div grade.etiquetasPorPagina;
    indiceNaPagina := posicaoAbsoluta mod grade.etiquetasPorPagina;
    etiquetaMm := calcularAreaEtiqueta(layout.configuracao, indiceNaPagina);
    etiqueta.indiceRegistro := indiceRegistro;
    etiqueta.indiceNaPagina := indiceNaPagina;
    etiqueta.areaPixels := converterAreaParaPixels(etiquetaMm, metricas);
    exigirValidade(obterErroAreaImprimivel(etiqueta.areaPixels, metricas));
    // Novo vetor a cada etiqueta: arrays dinamicos compartilham referencias.
    etiqueta.textos := nil;
    SetLength(etiqueta.textos, Length(layout.campos));
    for indiceCampo := 0 to High(layout.campos) do
    begin
      etiqueta.textos[indiceCampo].campo := layout.campos[indiceCampo];
      try
        etiqueta.textos[indiceCampo].texto := formatarCampo(layout.campos[indiceCampo], dados[indiceRegistro], formato);
      except
        on erro: Exception do
          raise ELabelError.CreateFmt('Registro %d, campo %s: %s',
            [indiceRegistro, layout.campos[indiceCampo].nome, erro.Message]);
      end;
      etiqueta.textos[indiceCampo].areaPixels := converterAreaParaPixels(
        calcularAreaCampo(etiquetaMm, layout.campos[indiceCampo]), metricas);
      exigirValidade(obterErroAreaImprimivel(etiqueta.textos[indiceCampo].areaPixels, metricas));
    end;
    indiceNoVetor := Length(Result.paginas[indicePagina].etiquetas);
    SetLength(Result.paginas[indicePagina].etiquetas, indiceNoVetor + 1);
    Result.paginas[indicePagina].etiquetas[indiceNoVetor] := etiqueta;
  end;
end;

end.
