unit labelTypes;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils;

type
  ELabelError = class(Exception);
  TTipoInformacao = (tiTexto, tiData, tiDecimal, tiInteiro);
  TOrigemInformacao = (oiFixa, oiVariavel);
  TAlinhamentoTexto = (atEsquerda, atCentro, atDireita);

  TAreaMilimetros = record
    esquerdaMm, topoMm, direitaMm, baseMm: Double;
  end;

  TAreaPixels = record
    esquerda, topo, direita, base: Integer;
  end;

  TMetricasImpressao = record
    resolucaoHorizontalDpi, resolucaoVerticalDpi: Integer;
    larguraFisicaPixels, alturaFisicaPixels: Integer;
    larguraImprimivelPixels, alturaImprimivelPixels: Integer;
    deslocamentoHorizontalPixels, deslocamentoVerticalPixels: Integer;
  end;

  TConfiguracaoLayout = record
    larguraMidiaMm, alturaPaginaMm: Double;
    larguraEtiquetaMm, alturaEtiquetaMm: Double;
    espacoEntreColunasMm, espacoEntreLinhasMm: Double;
    margemEsquerdaMm, margemSuperiorMm: Double;
    margemDireitaMm, margemInferiorMm: Double;
    quantidadeColunas: Integer;
  end;

  TCampoLayout = record
    nome: string;
    origem: TOrigemInformacao;
    tipoInformacao: TTipoInformacao;
    chaveVariavel, valorFixo, mascara, prefixo, sufixo: string;
    obrigatorio: Boolean;
    posicaoHorizontalMm, posicaoVerticalMm: Double;
    larguraMm, alturaMm: Double;
    nomeFonte: string;
    tamanhoFontePt: Double;
    negrito: Boolean;
    alinhamento: TAlinhamentoTexto;
  end;

  TCamposLayout = array of TCampoLayout;

  TDocumentoLayout = record
    versao: Integer;
    nome: string;
    configuracao: TConfiguracaoLayout;
    separadorDecimal, separadorMilhar: Char;
    campos: TCamposLayout;
  end;

  TValorNomeado = record
    nome, valor: string;
  end;
  TValoresNomeados = array of TValorNomeado;
  TRegistroDados = record
    valores: TValoresNomeados;
  end;
  TRegistrosDados = array of TRegistroDados;

  TGradeEtiquetas = record
    quantidadeLinhas, etiquetasPorPagina: Integer;
  end;

  TTextoPlanejado = record
    campo: TCampoLayout;
    texto: string;
    areaPixels: TAreaPixels;
  end;
  TTextosPlanejados = array of TTextoPlanejado;
  TEtiquetaPlanejada = record
    indiceRegistro, indiceNaPagina: Integer;
    areaPixels: TAreaPixels;
    textos: TTextosPlanejados;
  end;
  TEtiquetasPlanejadas = array of TEtiquetaPlanejada;
  TPaginaPlanejada = record
    etiquetas: TEtiquetasPlanejadas;
  end;
  TPaginasPlanejadas = array of TPaginaPlanejada;
  TPlanoImpressao = record
    nome: string;
    metricas: TMetricasImpressao;
    paginas: TPaginasPlanejadas;
  end;

implementation
end.
