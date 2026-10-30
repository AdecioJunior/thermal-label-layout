unit labelSvg;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}

interface

uses SysUtils, Classes, labelTypes, labelUtils;

function renderizarPaginaSvg(const plano: TPlanoImpressao; indicePagina: Integer): string;
procedure exportarPrevia(const plano: TPlanoImpressao; const pastaSaida: string);

implementation

function horizontalMm(posicaoPixels: Integer; const metricas: TMetricasImpressao): Double;
begin
  Result := (posicaoPixels + metricas.deslocamentoHorizontalPixels) *
    25.4 / metricas.resolucaoHorizontalDpi;
end;

function verticalMm(posicaoPixels: Integer; const metricas: TMetricasImpressao): Double;
begin
  Result := (posicaoPixels + metricas.deslocamentoVerticalPixels) *
    25.4 / metricas.resolucaoVerticalDpi;
end;

function retanguloSvg(const area: TAreaPixels; const metricas: TMetricasImpressao;
  const classe: string): string;
begin
  Result := '<rect class="' + classe + '" x="' + numeroSvg(horizontalMm(area.esquerda, metricas)) +
    '" y="' + numeroSvg(verticalMm(area.topo, metricas)) +
    '" width="' + numeroSvg((area.direita - area.esquerda) * 25.4 / metricas.resolucaoHorizontalDpi) +
    '" height="' + numeroSvg((area.base - area.topo) * 25.4 / metricas.resolucaoVerticalDpi) + '"/>';
end;

function renderizarTextoSvg(const textoPlanejado: TTextoPlanejado;
  const metricas: TMetricasImpressao): string;
var esquerdaMm, topoMm, larguraMm, alturaMm, tamanhoFonteMm, posicaoTextoMm: Double;
  ancora, pesoFonte: string;
begin
  if textoPlanejado.texto = '' then Exit('');
  esquerdaMm := horizontalMm(textoPlanejado.areaPixels.esquerda, metricas);
  topoMm := verticalMm(textoPlanejado.areaPixels.topo, metricas);
  larguraMm := (textoPlanejado.areaPixels.direita - textoPlanejado.areaPixels.esquerda) *
    25.4 / metricas.resolucaoHorizontalDpi;
  alturaMm := (textoPlanejado.areaPixels.base - textoPlanejado.areaPixels.topo) *
    25.4 / metricas.resolucaoVerticalDpi;
  tamanhoFonteMm := textoPlanejado.campo.tamanhoFontePt * 25.4 / 72;
  ancora := 'start';
  // Reserva para o avanco lateral dos glifos, mantendo a tinta dentro do campo.
  posicaoTextoMm := esquerdaMm + 0.3;
  if textoPlanejado.campo.alinhamento = atCentro then
  begin
    ancora := 'middle';
    posicaoTextoMm := esquerdaMm + larguraMm / 2;
  end;
  if textoPlanejado.campo.alinhamento = atDireita then
  begin
    ancora := 'end';
    posicaoTextoMm := esquerdaMm + larguraMm - 0.3;
  end;
  pesoFonte := 'normal';
  if textoPlanejado.campo.negrito then pesoFonte := 'bold';
  Result := retanguloSvg(textoPlanejado.areaPixels, metricas, 'fieldGuide') +
    '<text data-field="' + escaparXml(textoPlanejado.campo.nome) +
    '" data-left="' + numeroSvg(esquerdaMm) + '" data-top="' + numeroSvg(topoMm) +
    '" data-width="' + numeroSvg(larguraMm) + '" data-height="' + numeroSvg(alturaMm) +
    '" x="' + numeroSvg(posicaoTextoMm) + '" y="' + numeroSvg(topoMm + tamanhoFonteMm) +
    '" font-family="' + escaparXml(textoPlanejado.campo.nomeFonte) + ', sans-serif"' +
    ' style="font-size:' + numeroSvg(tamanhoFonteMm) + 'px" font-weight="' + pesoFonte +
    '" text-anchor="' + ancora + '">' + escaparXml(textoPlanejado.texto) + '</text>';
end;

function renderizarPaginaSvg(const plano: TPlanoImpressao; indicePagina: Integer): string;
var linhas: TStringList; indiceEtiqueta, indiceTexto: Integer;
  larguraPaginaMm, alturaPaginaMm: Double; areaImprimivel: TAreaPixels;
begin
  if indicePagina < 0 then raise ELabelError.Create('Indice de pagina negativo.');
  if indicePagina >= Length(plano.paginas) then raise ELabelError.Create('Pagina inexistente.');
  larguraPaginaMm := plano.metricas.larguraFisicaPixels * 25.4 / plano.metricas.resolucaoHorizontalDpi;
  alturaPaginaMm := plano.metricas.alturaFisicaPixels * 25.4 / plano.metricas.resolucaoVerticalDpi;
  linhas := TStringList.Create;
  try
    linhas.Add('<svg xmlns="http://www.w3.org/2000/svg" width="' + numeroSvg(larguraPaginaMm) +
      'mm" height="' + numeroSvg(alturaPaginaMm) + 'mm" viewBox="0 0 ' +
      numeroSvg(larguraPaginaMm) + ' ' + numeroSvg(alturaPaginaMm) + '">');
    linhas.Add('<title>' + escaparXml(plano.nome) + ' - pagina ' + IntToStr(indicePagina + 1) + '</title>');
    linhas.Add('<style>text{fill:#111}.labelGuide{fill:none;stroke:#6b7280;stroke-width:.12}' +
      '.fieldGuide{fill:none;stroke:#cbd5e1;stroke-width:.06}.printableGuide{fill:none;' +
      'stroke:#2563eb;stroke-width:.15;stroke-dasharray:.8 .5}.overflow{fill:#b91c1c}</style>');
    linhas.Add('<rect width="100%" height="100%" fill="white"/>');
    areaImprimivel.esquerda := 0;
    areaImprimivel.topo := 0;
    areaImprimivel.direita := plano.metricas.larguraImprimivelPixels;
    areaImprimivel.base := plano.metricas.alturaImprimivelPixels;
    linhas.Add(retanguloSvg(areaImprimivel, plano.metricas, 'printableGuide'));
    for indiceEtiqueta := 0 to High(plano.paginas[indicePagina].etiquetas) do
    begin
      linhas.Add('<g data-record="' + IntToStr(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].indiceRegistro) +
        '" data-slot="' + IntToStr(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].indiceNaPagina) + '">');
      linhas.Add(retanguloSvg(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].areaPixels,
        plano.metricas, 'labelGuide'));
      for indiceTexto := 0 to High(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos) do
        linhas.Add(renderizarTextoSvg(plano.paginas[indicePagina].etiquetas[indiceEtiqueta].textos[indiceTexto], plano.metricas));
      linhas.Add('</g>');
    end;
    linhas.Add('</svg>');
    Result := linhas.Text;
  finally linhas.Free; end;
end;

procedure exportarPrevia(const plano: TPlanoImpressao; const pastaSaida: string);
var html: TStringList; indicePagina: Integer; paginaSvg, nomeArquivo: string;
  larguraPaginaMm, alturaPaginaMm: Double;
begin
  if Length(plano.paginas) = 0 then raise ELabelError.Create('Plano sem paginas.');
  if not ForceDirectories(pastaSaida) then raise ELabelError.Create('Nao foi possivel criar a pasta de saida.');
  larguraPaginaMm := plano.metricas.larguraFisicaPixels * 25.4 / plano.metricas.resolucaoHorizontalDpi;
  alturaPaginaMm := plano.metricas.alturaFisicaPixels * 25.4 / plano.metricas.resolucaoVerticalDpi;
  html := TStringList.Create;
  try
    html.Add('<!doctype html><html lang="pt-BR"><meta charset="utf-8">');
    html.Add('<meta name="viewport" content="width=device-width, initial-scale=1">');
    html.Add('<title>' + escaparXml(plano.nome) + ' - previa</title><style>');
    html.Add('body{margin:0;background:#e8edf2;color:#17202a;font:15px system-ui,sans-serif}' +
      'header{padding:24px 32px;background:#102c3c;color:white}h1{margin:0 0 8px;font-size:24px}' +
      'header p{max-width:850px;line-height:1.5}button{padding:10px 18px;border:0;border-radius:6px;' +
      'background:#bce8cf;color:#102c3c;font-weight:700;cursor:pointer}button:disabled{opacity:.5;cursor:not-allowed}.status{padding:16px 32px}' +
      '.page{margin:20px 32px;width:max-content;max-width:calc(100% - 64px)}.page svg{display:block;' +
      'max-width:100%;height:auto;box-shadow:0 3px 16px #0002}.page p{font-weight:600}' +
      '.error{color:#b91c1c;font-weight:600}.hideGuides .labelGuide{display:none}' +
      '.hideGuides .fieldGuide{display:none}.hideGuides .printableGuide{display:none}');
    html.Add('@page{size:' + numeroSvg(larguraPaginaMm) + 'mm ' + numeroSvg(alturaPaginaMm) + 'mm;margin:0}' +
      '@media print{body{background:white}header,.status,.page p{display:none}.page{margin:0;' +
      'max-width:none;break-after:page}.page:last-child{break-after:auto}.page svg{max-width:none;' +
      'box-shadow:none}.labelGuide,.fieldGuide,.printableGuide{display:none}}');
    html.Add('</style><header><h1>' + escaparXml(plano.nome) + '</h1>');
    html.Add('<p>Prévia geométrica gerada pelo núcleo Pascal. Contornos mostram etiquetas, campos e área imprimível. ' +
      'A verificação abaixo mede as fontes deste navegador; não substitui o driver nem a impressora física.</p>');
    html.Add('<button id="guides">Mostrar/ocultar guias</button> <button id="print">Imprimir / salvar PDF</button></header>');
    html.Add('<div class="status" id="status" role="status" aria-live="polite">Verificando textos...</div>');
    for indicePagina := 0 to High(plano.paginas) do
    begin
      paginaSvg := renderizarPaginaSvg(plano, indicePagina);
      nomeArquivo := Format('page-%.3d.svg', [indicePagina + 1]);
      salvarTextoUtf8(IncludeTrailingPathDelimiter(pastaSaida) + nomeArquivo, paginaSvg);
      html.Add('<section class="page"><p>P&#225;gina ' + IntToStr(indicePagina + 1) + ' / ' +
        IntToStr(Length(plano.paginas)) + '</p>' + paginaSvg + '</section>');
    end;
    html.Add('<script>let overflowCount=0;const statusBox=document.getElementById("status");');
    html.Add('function isOutsideArea(text){const bounds=text.getBBox(),left=Number(text.dataset.left),' +
      'top=Number(text.dataset.top),width=Number(text.dataset.width),height=Number(text.dataset.height),tolerance=.05;' +
      'text.dataset.measuredBounds=[bounds.x,bounds.y,bounds.width,bounds.height].join(",");' +
      'if(bounds.x<left-tolerance)return true;if(bounds.y<top-tolerance)return true;' +
      'if(bounds.x+bounds.width>left+width+tolerance)return true;' +
      'if(bounds.y+bounds.height>top+height+tolerance)return true;return false;}');
    html.Add('function inspectText(){overflowCount=0;document.querySelectorAll("text[data-field]").forEach(text=>{' +
      'const outside=isOutsideArea(text);text.classList.toggle("overflow",outside);if(outside)overflowCount++;});' +
      'statusBox.textContent=overflowCount?overflowCount+" campo(s) excedem sua área neste navegador. Revise o layout antes de imprimir.":' +
      '"Todos os textos cabem nas áreas declaradas neste navegador.";' +
      'statusBox.classList.toggle("error",overflowCount>0);document.getElementById("print").disabled=overflowCount>0;}');
    html.Add('document.fonts.ready.then(inspectText);document.getElementById("guides").onclick=()=>document.body.classList.toggle("hideGuides");' +
      'document.getElementById("print").onclick=()=>{inspectText();if(overflowCount)return;window.print();};');
    html.Add('</script></html>');
    salvarTextoUtf8(IncludeTrailingPathDelimiter(pastaSaida) + 'preview.html', html.Text);
  finally html.Free; end;
end;

end.
