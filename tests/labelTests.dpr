program labelTests;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}
{$APPTYPE CONSOLE}

uses SysUtils, Classes, Math, labelTypes, labelUtils, labelLayout, labelData,
  labelGeometry, labelFormatting, labelPlan, labelSvg;

type
  TProcedimentoTeste = procedure;
  TCenarioInvalido = (ciColunasExcedentes, ciAlturaInsuficiente,
    ciMargemFisica, ciDpiZero, ciIndiceInicial, ciCampoFora,
    ciDataInvalida, ciDecimalInvalido, ciDadoAusente, ciVersao,
    ciChaveDesconhecida, ciTipoDesconhecido, ciCampoAmbiguo,
    ciMascaraTexto, ciMascaraInteiro, ciMidiaDivergente);

var quantidadeTestes, quantidadeVerificacoes: Integer;

procedure verificar(condicao: Boolean; const mensagem: string);
begin
  Inc(quantidadeVerificacoes);
  if condicao then Exit;
  raise Exception.Create(mensagem);
end;

procedure verificarPerto(esperado, encontrado, tolerancia: Double; const mensagem: string);
begin
  verificar(Abs(esperado - encontrado) <= tolerancia, mensagem);
end;

procedure executarTeste(const nome: string; procedimento: TProcedimentoTeste);
begin
  procedimento;
  Inc(quantidadeTestes);
  WriteLn('PASS ', nome);
end;

function layoutPadrao: TDocumentoLayout;
begin
  Result := carregarLayout('examples/labels-5.lay');
end;

procedure testarTresApresentacoes;
const colunas: array[0..2] of Integer = (3, 5, 6);
var indiceApresentacao: Integer; layout: TDocumentoLayout;
  metricas: TMetricasImpressao; grade: TGradeEtiquetas;
begin
  for indiceApresentacao := Low(colunas) to High(colunas) do
  begin
    layout := carregarLayout('examples/labels-' + IntToStr(colunas[indiceApresentacao]) + '.lay');
    metricas := criarMetricasSimuladas(layout.configuracao, 203, 203);
    grade := calcularGrade(layout.configuracao, metricas);
    verificar(grade.quantidadeLinhas = 2, 'Deveriam caber duas fileiras.');
    verificar(grade.etiquetasPorPagina = 2 * colunas[indiceApresentacao], 'Capacidade incorreta.');
  end;
end;

procedure testarSaltoColunasELinhas;
var layout: TDocumentoLayout; area: TAreaMilimetros;
begin
  layout := layoutPadrao;
  area := calcularAreaEtiqueta(layout.configuracao, 4);
  verificarPerto(82, area.esquerdaMm, 1E-8, 'Quinta coluna deve comecar em 82 mm.');
  verificarPerto(100, area.direitaMm, 1E-8, 'Quinta coluna deve terminar em 100 mm.');
  area := calcularAreaEtiqueta(layout.configuracao, 5);
  verificarPerto(2, area.esquerdaMm, 1E-8, 'Nova linha deve voltar para a primeira coluna.');
  verificarPerto(28, area.topoMm, 1E-8, 'Nova linha deve respeitar altura mais intervalo.');
end;

procedure testarResolucaoSemDesvio;
const resolucoes: array[0..2] of Integer = (203, 300, 600);
var layout: TDocumentoLayout; metricas: TMetricasImpressao;
  areaMm: TAreaMilimetros; areaPixels: TAreaPixels; indiceResolucao: Integer;
  posicaoFisicaMm, erroMaximoMm: Double;
begin
  layout := layoutPadrao;
  layout.configuracao.quantidadeColunas := 19;
  layout.configuracao.larguraEtiquetaMm := 3.1;
  layout.configuracao.espacoEntreColunasMm := 1.2;
  areaMm := calcularAreaEtiqueta(layout.configuracao, 18);
  verificarPerto(79.4, areaMm.esquerdaMm, 1E-8, 'Passo fisico independente de DPI.');
  for indiceResolucao := Low(resolucoes) to High(resolucoes) do
  begin
    metricas := criarMetricasSimuladas(layout.configuracao, resolucoes[indiceResolucao], resolucoes[indiceResolucao]);
    areaPixels := converterAreaParaPixels(areaMm, metricas);
    posicaoFisicaMm := areaPixels.esquerda * 25.4 / resolucoes[indiceResolucao];
    erroMaximoMm := 0.500001 * 25.4 / resolucoes[indiceResolucao];
    verificarPerto(79.4, posicaoFisicaMm, erroMaximoMm, 'Arredondamento acumulado na ultima coluna.');
  end;
end;

procedure testarDpiIndependenteEOffsets;
var layout: TDocumentoLayout; metricas: TMetricasImpressao; area: TAreaPixels;
  grade: TGradeEtiquetas;
begin
  layout := layoutPadrao;
  metricas := criarMetricasSimuladas(layout.configuracao, 203, 300);
  metricas.deslocamentoHorizontalPixels := 8;
  metricas.deslocamentoVerticalPixels := 12;
  Dec(metricas.larguraImprimivelPixels, 16);
  Dec(metricas.alturaImprimivelPixels, 24);
  grade := calcularGrade(layout.configuracao, metricas);
  area := converterAreaParaPixels(calcularAreaEtiqueta(layout.configuracao, 0), metricas);
  verificar(area.esquerda = 8, 'Offset X deve ser subtraido uma unica vez.');
  verificar(area.topo = 12, 'Offset Y deve respeitar DPI vertical.');
  verificar(grade.etiquetasPorPagina = 10, 'Margens fisicas pequenas devem ser aceitas.');
end;

procedure testarPaginacaoESaltoInicial;
var layout: TDocumentoLayout; dados: TRegistrosDados;
  metricas: TMetricasImpressao; plano: TPlanoImpressao;
begin
  layout := layoutPadrao;
  dados := carregarDados('examples/sample-data.ini');
  metricas := criarMetricasSimuladas(layout.configuracao, 203, 203);
  plano := montarPlano(layout, dados, metricas, 2);
  verificar(Length(plano.paginas) = 2, '13 registros com salto 2 devem gerar duas paginas.');
  verificar(Length(plano.paginas[0].etiquetas) = 8, 'Primeira pagina deve reservar os dois primeiros slots.');
  verificar(plano.paginas[0].etiquetas[0].indiceNaPagina = 2, 'Slot inicial incorreto.');
  verificar(plano.paginas[1].etiquetas[0].indiceNaPagina = 0, 'Nova pagina deve recomecar no slot zero.');
  verificar(plano.paginas[1].etiquetas[0].indiceRegistro = 8, 'Lote perdeu continuidade entre paginas.');
  verificar(plano.paginas[0].etiquetas[0].textos[5].texto = '#001', 'Primeiro texto foi sobrescrito por outro registro.');
  verificar(plano.paginas[1].etiquetas[4].textos[5].texto = '#013', 'Ultimo registro incorreto.');
end;

procedure testarFormatacaoTipada;
var layout: TDocumentoLayout; dados: TRegistrosDados; formato: TFormatSettings;
  campo: TCampoLayout;
begin
  layout := layoutPadrao;
  dados := carregarDados('examples/sample-data.ini');
  formato := criarFormatoSaida(layout);
  verificar(formatarCampo(layout.campos[0], dados[0], formato) = 'AMOSTRA', 'Texto fixo incorreto.');
  verificar(formatarCampo(layout.campos[2], dados[0], formato) = 'L:L001', 'Mascara textual incorreta.');
  verificar(formatarCampo(layout.campos[3], dados[0], formato) = 'Dt:29/02/28', 'Data ISO bissexta incorreta.');
  verificar(obterErroInteiroCanonico('$FF') <> '', 'Hexadecimal deve ser rejeitado.');
  verificar(obterErroInteiroCanonico('+12') <> '', 'Sinal positivo deve ser rejeitado.');
  verificar(obterErroInteiroCanonico('-') <> '', 'Sinal isolado deve ser rejeitado.');
  verificar(obterErroInteiroCanonico('-123') = '', 'Inteiro decimal negativo deve ser aceito.');
  verificar(formatarCampo(layout.campos[4], dados[0], formato) = 'R$1.250,50', 'Decimal pt-BR incorreto.');
  formato.DecimalSeparator := '.';
  formato.ThousandSeparator := ',';
  verificar(formatarCampo(layout.campos[4], dados[0], formato) = 'R$1,250.50', 'Formato explicito dependeu do SO.');
  campo := layout.campos[5];
  campo.origem := oiFixa;
  campo.valorFixo := '9223372036854775807';
  verificar(formatarCampo(campo, dados[0], formato) = '#9223372036854775807', 'Int64 perdeu precisao.');
  campo.valorFixo := '-7';
  verificar(formatarCampo(campo, dados[0], formato) = '#-007', 'Preenchimento de inteiro negativo incorreto.');
  campo := layout.campos[4];
  campo.origem := oiFixa;
  campo.valorFixo := '-12.3456';
  campo.mascara := '0.0000';
  campo.prefixo := '';
  verificar(formatarCampo(campo, dados[0], formato) = '-12.3456', 'Currency com quatro casas incorreto.');
end;

procedure testarEntradasCanonicas;
var data: TDateTime;
begin
  verificar(tentarLerDataIso('2028-02-29', data), 'Ano bissexto deveria ser aceito.');
  verificar(not tentarLerDataIso('2029-02-29', data), 'Dia inexistente deveria ser rejeitado.');
  verificar(not tentarLerDataIso('2028-2-29', data), 'Data fora do contrato ISO deveria falhar.');
  verificar(not tentarLerDataIso('2028-01-01T00:00:00Z', data), 'Date nao deve aceitar datetime implicitamente.');
  verificar(obterErroDecimalCanonico('12.34567') <> '', 'Entrada com cinco casas nao deve ser arredondada silenciosamente.');
  verificar(obterErroDecimalCanonico('1,25') <> '', 'Virgula nao deve ser interpretada como decimal de entrada.');
  verificar(obterErroDecimalCanonico('NaN') <> '', 'NaN deve ser rejeitado.');
  verificar(obterErroDecimalCanonico('1e3') <> '', 'Expoente fora do contrato deve falhar.');
  verificar(obterErroDecimalCanonico('-.5') <> '', 'Decimal sem parte inteira deve falhar.');
end;

procedure testarCampoOpcional;
var layout: TDocumentoLayout; dados: TRegistrosDados; campo: TCampoLayout;
begin
  layout := layoutPadrao;
  dados := carregarDados('examples/sample-data.ini');
  campo := layout.campos[1];
  campo.chaveVariavel := 'inexistente';
  campo.obrigatorio := False;
  campo.prefixo := 'Nao deve aparecer';
  verificar(formatarCampo(campo, dados[0], criarFormatoSaida(layout)) = '', 'Opcional ausente deve omitir tambem o prefixo.');
end;

procedure testarUnicodeEXml;
var layout: TDocumentoLayout; dados: TRegistrosDados; metricas: TMetricasImpressao;
  plano: TPlanoImpressao; svg: string;
begin
  layout := layoutPadrao;
  dados := carregarDados('examples/sample-data.ini');
  dados[0].valores[0].valor := 'Solução <script> & "teste"';
  metricas := criarMetricasSimuladas(layout.configuracao, 203, 203);
  plano := montarPlano(layout, dados, metricas, 0);
  svg := renderizarPaginaSvg(plano, 0);
  verificar(Pos('Solução &lt;script&gt; &amp; &quot;teste&quot;', svg) > 0, 'Texto UTF-8 ou escape XML incorreto.');
  verificar(Pos('<script>', svg) = 0, 'Dados foram interpretados como markup.');
end;

procedure executarCenarioInvalido(cenario: TCenarioInvalido);
var layout: TDocumentoLayout; dados: TRegistrosDados; metricas: TMetricasImpressao;
  plano: TPlanoImpressao; conteudo: TStringList; textoArquivo: string;
  indiceInicial: Integer;
begin
  layout := layoutPadrao;
  dados := carregarDados('examples/sample-data.ini');
  metricas := criarMetricasSimuladas(layout.configuracao, 203, 203);
  indiceInicial := 0;
  case cenario of
    ciColunasExcedentes: layout.configuracao.quantidadeColunas := 6;
    ciAlturaInsuficiente: layout.configuracao.alturaEtiquetaMm := 100;
    ciMargemFisica: begin
      metricas.deslocamentoHorizontalPixels := 30;
      Dec(metricas.larguraImprimivelPixels, 30);
    end;
    ciDpiZero: metricas.resolucaoHorizontalDpi := 0;
    ciIndiceInicial: indiceInicial := 10;
    ciCampoFora: layout.campos[0].larguraMm := 200;
    ciDataInvalida: dados[High(dados)].valores[2].valor := '2029-02-29';
    ciDecimalInvalido: dados[High(dados)].valores[3].valor := '12.34567';
    ciDadoAusente: layout.campos[1].chaveVariavel := 'inexistente';
    ciMascaraTexto: layout.campos[1].mascara := '{value}{value}';
    ciMascaraInteiro: layout.campos[5].mascara := '0.00';
    ciMidiaDivergente: Inc(metricas.larguraFisicaPixels, 100);
    ciVersao, ciChaveDesconhecida, ciTipoDesconhecido, ciCampoAmbiguo:
    begin
      conteudo := carregarLinhasUtf8('examples/labels-5.lay');
      try textoArquivo := conteudo.Text; finally conteudo.Free; end;
      case cenario of
        ciVersao: textoArquivo := StringReplace(textoArquivo, 'version=1', 'version=9', []);
        ciChaveDesconhecida: textoArquivo := StringReplace(textoArquivo, 'columns=5', 'colums=5', []);
        ciTipoDesconhecido: textoArquivo := StringReplace(textoArquivo, 'type=text', 'type=script', []);
        ciCampoAmbiguo: textoArquivo := StringReplace(textoArquivo, 'value=AMOSTRA', 'value=AMOSTRA' + sLineBreak + 'bind=descricao', []);
      end;
      salvarTextoUtf8('build/invalid-layout.lay', textoArquivo);
      layout := carregarLayout('build/invalid-layout.lay');
    end;
  end;
  plano := montarPlano(layout, dados, metricas, indiceInicial);
  if Length(plano.paginas) = 0 then Exit;
end;

procedure testarRejeicoes;
var cenario: TCenarioInvalido; rejeitado: Boolean;
begin
  for cenario := Low(TCenarioInvalido) to High(TCenarioInvalido) do
  begin
    rejeitado := False;
    try
      executarCenarioInvalido(cenario);
    except
      on erro: ELabelError do rejeitado := erro.Message <> '';
    end;
    verificar(rejeitado, 'Cenario invalido aceito: ' + IntToStr(Ord(cenario)));
  end;
end;

begin
  try
    quantidadeTestes := 0;
    quantidadeVerificacoes := 0;
    ForceDirectories('build');
    executarTeste('grades de 3, 5 e 6 colunas', testarTresApresentacoes);
    executarTeste('salto de coluna e fileira', testarSaltoColunasELinhas);
    executarTeste('203/300/600 DPI sem desvio acumulado', testarResolucaoSemDesvio);
    executarTeste('DPI por eixo e offsets fisicos', testarDpiIndependenteEOffsets);
    executarTeste('paginacao, slots usados e independencia dos registros', testarPaginacaoESaltoInicial);
    executarTeste('tipos, mascaras, locale explicito e Int64', testarFormatacaoTipada);
    executarTeste('datas e decimais canonicos', testarEntradasCanonicas);
    executarTeste('variavel opcional', testarCampoOpcional);
    executarTeste('Unicode e escape XML', testarUnicodeEXml);
    executarTeste('rejeicoes e preflight do lote completo', testarRejeicoes);
    WriteLn('OK: ', quantidadeTestes, ' grupos; ', quantidadeVerificacoes, ' verificacoes.');
  except
    on erro: Exception do
    begin
      WriteLn(StdErr, 'FAIL: ', erro.Message);
      Halt(1);
    end;
  end;
end.
