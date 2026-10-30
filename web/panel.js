'use strict';

const byId = id => document.getElementById(id);
const pageKeys = ['pageWidthMm', 'pageHeightMm', 'labelWidthMm', 'labelHeightMm', 'columns',
  'columnGapMm', 'rowGapMm', 'marginLeftMm', 'marginTopMm', 'marginRightMm', 'marginBottomMm'];
const fieldControls = {
  fieldSource: 'source', fieldType: 'type', fieldBind: 'bind', fieldValue: 'value',
  fieldMask: 'mask', fieldPrefix: 'prefix', fieldSuffix: 'suffix', fieldX: 'xMm',
  fieldY: 'yMm', fieldWidth: 'widthMm', fieldHeight: 'heightMm', fieldFont: 'fontFamily',
  fieldFontSize: 'fontSizePt', fieldAlign: 'align'
};
const state = {layout: null, presets: {}, session: '', selectedField: 0, preview: null,
  rawLayoutDirty: false, busy: false, revision: 0};

function parseIni(text) {
  const sections = new Map();
  let currentSection = null;
  for (const [lineIndex, rawLine] of text.replace(/^\uFEFF/, '').split(/\r?\n/).entries()) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith(';')) continue;
    if (line.startsWith('[')) {
      if (!line.endsWith(']')) throw new Error(`Linha ${lineIndex + 1}: seção sem fechamento.`);
      const sectionName = line.slice(1, -1);
      if (sections.has(sectionName)) throw new Error(`Seção repetida: ${sectionName}.`);
      currentSection = new Map();
      sections.set(sectionName, currentSection);
      continue;
    }
    if (!currentSection) throw new Error(`Linha ${lineIndex + 1}: informe uma seção antes dos valores.`);
    const separatorIndex = line.indexOf('=');
    if (separatorIndex < 1) throw new Error(`Linha ${lineIndex + 1}: use chave=valor.`);
    const key = line.slice(0, separatorIndex).trim();
    if (currentSection.has(key)) throw new Error(`Chave repetida: ${key}.`);
    currentSection.set(key, line.slice(separatorIndex + 1).trim());
  }
  return sections;
}

function parseLayout(text) {
  const sections = parseIni(text);
  if (!sections.has('layout')) throw new Error('O arquivo precisa da seção [layout].');
  if (!sections.has('format')) throw new Error('O arquivo precisa da seção [format].');
  const fields = [];
  for (const [sectionName, values] of sections) {
    if (sectionName === 'layout') continue;
    if (sectionName === 'format') continue;
    if (!sectionName.startsWith('field.')) throw new Error(`Seção desconhecida: ${sectionName}.`);
    fields.push({name: sectionName.slice(6), values: Object.fromEntries(values)});
  }
  if (!fields.length) throw new Error('Adicione pelo menos um campo ao layout.');
  return {page: Object.fromEntries(sections.get('layout')), format: Object.fromEntries(sections.get('format')), fields};
}

function serializeSections(sections) {
  return [...sections].map(([name, values]) => `[${name}]\n${[...values].map(([key, value]) => `${key}=${value}`).join('\n')}`).join('\n\n') + '\n';
}

function layoutText() {
  const sections = new Map([
    ['layout', new Map(Object.entries(state.layout.page))],
    ['format', new Map(Object.entries(state.layout.format))]
  ]);
  const names = new Set();
  for (const field of state.layout.fields) {
    if (!field.name) throw new Error('Informe um nome para cada campo.');
    if (/[\[\]\r\n=]/.test(field.name)) throw new Error('O nome do campo não pode conter colchetes, quebra de linha ou sinal de igual.');
    if (names.has(field.name)) throw new Error(`Nome de campo repetido: ${field.name}.`);
    names.add(field.name);
    sections.set(`field.${field.name}`, new Map(Object.entries(field.values)));
  }
  return serializeSections(sections);
}

function setFeedback(message, kind = '') {
  byId('feedback').textContent = message;
  byId('feedback').className = `feedback ${kind}`;
}

function markDirty() {
  state.revision++;
  byId('revision').textContent = 'Alterações pendentes';
  byId('revision').classList.add('dirty');
  byId('printPreview').disabled = true;
  byId('downloadSvg').disabled = true;
  setFeedback('Você alterou o projeto. Clique em “Gerar prévia” para atualizar o resultado.', 'pending');
}

function syncLayoutSource() {
  if (state.rawLayoutDirty) return;
  try { byId('layoutSource').value = layoutText(); }
  catch (error) { setFeedback(error.message, 'error'); }
}

function refreshFieldList() {
  const options = state.layout.fields.map((field, fieldIndex) => {
    const option = document.createElement('option');
    option.value = fieldIndex;
    option.textContent = field.name || '(sem nome)';
    return option;
  });
  byId('selectedField').replaceChildren(...options);
  byId('selectedField').value = state.selectedField;
  byId('fieldCount').textContent = `${options.length} campos`;
  byId('removeField').disabled = options.length <= 1;
}

function showSourceControls() {
  const isVariable = byId('fieldSource').value === 'variable';
  byId('bindingLabel').hidden = !isVariable;
  byId('fixedValueLabel').hidden = isVariable;
  byId('sampleEditor').hidden = !isVariable;
  const type = byId('fieldType').value;
  const hints = {
    text: 'Texto: use {value} para inserir o dado na máscara, ou deixe a máscara vazia.',
    date: 'Data de entrada: YYYY-MM-DD. Exemplo: 2028-02-29. Máscara: dd/mm/yy.',
    decimal: 'Entrada: 1250.50, com ponto e até quatro casas. Máscara de saída: #,##0.00.',
    integer: 'Inteiro decimal, sem separador. A máscara 000 exibe 7 como 007.'
  };
  byId('typeHint').textContent = hints[type] || '';
}

function readSampleValue() {
  try {
    const records = parseIni(byId('dataSource').value);
    return records.get('record.0')?.get(byId('fieldBind').value) ?? '';
  } catch { return ''; }
}

function selectField(fieldIndex) {
  state.selectedField = fieldIndex;
  const field = state.layout.fields[fieldIndex];
  byId('selectedField').value = fieldIndex;
  byId('fieldName').value = field.name;
  const defaults = {source: 'fixed', type: 'text', fontFamily: 'Arial', align: 'left'};
  for (const [controlId, key] of Object.entries(fieldControls)) {
    byId(controlId).value = field.values[key] ?? defaults[key] ?? '';
  }
  byId('fieldBold').checked = field.values.bold === 'true';
  byId('fieldRequired').checked = field.values.required !== 'false';
  byId('sampleValue').value = readSampleValue();
  showSourceControls();
  highlightSelectedField();
}

function highlightSelectedField() {
  const selectedName = state.layout.fields[state.selectedField]?.name;
  for (const text of byId('pages').querySelectorAll('text[data-field]')) {
    text.classList.toggle('selectedField', text.dataset.field === selectedName);
  }
}

function showLayout() {
  byId('layoutName').value = state.layout.page.name ?? '';
  for (const key of pageKeys) byId(key).value = state.layout.page[key] ?? '';
  byId('decimalSeparator').value = state.layout.format.decimalSeparator ?? ',';
  state.selectedField = Math.min(state.selectedField, state.layout.fields.length - 1);
  refreshFieldList();
  selectField(state.selectedField);
  syncLayoutSource();
}

function updateField() {
  const field = state.layout.fields[state.selectedField];
  field.name = byId('fieldName').value;
  for (const [controlId, key] of Object.entries(fieldControls)) field.values[key] = byId(controlId).value;
  field.values.bold = String(byId('fieldBold').checked);
  field.values.required = String(byId('fieldRequired').checked);
  if (field.values.source === 'fixed') delete field.values.bind;
  if (field.values.source === 'variable') delete field.values.value;
  refreshFieldList();
  showSourceControls();
  syncLayoutSource();
  markDirty();
}

function applyRawLayout() {
  const layout = parseLayout(byId('layoutSource').value);
  state.layout = layout;
  state.rawLayoutDirty = false;
  state.selectedField = 0;
  showLayout();
}

function checkFieldBounds(text) {
  const bounds = text.getBBox();
  text.dataset.measuredBounds = [bounds.x, bounds.y, bounds.width, bounds.height].join(',');
  const left = Number(text.dataset.left);
  const top = Number(text.dataset.top);
  const width = Number(text.dataset.width);
  const height = Number(text.dataset.height);
  const tolerance = 0.05;
  if (bounds.x < left - tolerance) return false;
  if (bounds.y < top - tolerance) return false;
  if (bounds.x + bounds.width > left + width + tolerance) return false;
  if (bounds.y + bounds.height > top + height + tolerance) return false;
  return true;
}

function inspectText() {
  const overflowingFields = [];
  for (const text of byId('pages').querySelectorAll('text[data-field]')) {
    const fits = checkFieldBounds(text);
    text.classList.toggle('overflow', !fits);
    if (!fits) overflowingFields.push(text.dataset.field);
  }
  if (overflowingFields.length) {
    const fieldNames = [...new Set(overflowingFields)].join(', ');
    setFeedback(`${overflowingFields.length} ocorrência(s) excedem a área do campo: ${fieldNames}. Ajuste as medidas ou a fonte e gere outra prévia.`, 'error');
    byId('printPreview').disabled = true;
    return false;
  }
  setFeedback('Layout válido. Os textos cabem nas áreas declaradas neste navegador. Clique em um texto para selecionar seu campo.');
  byId('printPreview').disabled = false;
  return true;
}

function updateZoom() {
  if (!state.preview) return;
  const zoom = Number(byId('zoom').value);
  for (const page of byId('pages').querySelectorAll('.page')) {
    page.style.width = `${state.preview.pageWidthMm * 96 / 25.4 * zoom}px`;
  }
}

function renderPages(preview) {
  const pages = preview.pages.map((svg, pageIndex) => {
    const page = document.createElement('section');
    page.className = 'page';
    const heading = document.createElement('div');
    heading.className = 'pageTitle';
    const title = document.createElement('span');
    title.textContent = `Página ${pageIndex + 1} de ${preview.pages.length}`;
    const dimensions = document.createElement('span');
    dimensions.textContent = `${preview.pageWidthMm} × ${preview.pageHeightMm} mm`;
    heading.append(title, dimensions);
    const drawing = document.createElement('div');
    // O SVG vem exclusivamente do renderizador Pascal, que escapa textos e atributos.
    drawing.innerHTML = svg;
    page.append(heading, drawing);
    return page;
  });
  byId('pages').replaceChildren(...pages);
  byId('pages').style.setProperty('--pageWidth', `${preview.pageWidthMm}mm`);
  let printStyle = byId('printPageSize');
  if (!printStyle) {
    printStyle = document.createElement('style');
    printStyle.id = 'printPageSize';
    document.head.append(printStyle);
  }
  printStyle.textContent = `@page{size:${Number(preview.pageWidthMm)}mm ${Number(preview.pageHeightMm)}mm;margin:0}`;
  updateZoom();
  highlightSelectedField();
}

async function generatePreview() {
  if (state.busy) return;
  const button = byId('generatePreview');
  state.busy = true;
  button.disabled = true;
  button.textContent = 'Gerando…';
  byId('printPreview').disabled = true;
  byId('downloadSvg').disabled = true;
  try {
    if (state.rawLayoutDirty) applyRawLayout();
    const currentRevision = state.revision;
    const request = {layout: layoutText(), data: byId('dataSource').value,
      dpi: Number(byId('dpi').value), startIndex: Number(byId('startIndex').value)};
    setFeedback('Calculando o lote…');
    const response = await fetch('/api/preview', {method: 'POST', headers: {
      'Content-Type': 'application/json', 'X-Label-Session': state.session
    }, body: JSON.stringify(request)});
    const preview = await response.json();
    if (!response.ok) throw new Error(preview.error || 'Não foi possível gerar a prévia.');
    if (currentRevision !== state.revision) {
      setFeedback('O projeto mudou durante a geração. Clique em “Gerar prévia” novamente.', 'pending');
      return;
    }
    state.preview = preview;
    renderPages(preview);
    await document.fonts.ready;
    if (currentRevision !== state.revision) { markDirty(); return; }
    byId('batchSummary').textContent = `${preview.records} registros · ${preview.pages.length} páginas · ${preview.capacity} posições por página · ${preview.rows} linhas`;
    byId('revision').textContent = 'Prévia atualizada';
    byId('revision').classList.remove('dirty');
    byId('downloadSvg').disabled = false;
    inspectText();
  } catch (error) {
    state.preview = null;
    byId('pages').replaceChildren();
    byId('batchSummary').textContent = 'Corrija o projeto para gerar uma nova prévia.';
    byId('revision').textContent = 'Revisar layout';
    byId('revision').classList.add('dirty');
    setFeedback(error.message === 'Failed to fetch' ? 'O gerador foi encerrado. Execute o projeto novamente no Lazarus e recarregue esta página.' : error.message, 'error');
  } finally {
    state.busy = false;
    button.disabled = false;
    button.textContent = 'Gerar prévia ↗';
  }
}

function downloadFile(name, text, mime = 'text/plain;charset=utf-8') {
  const url = URL.createObjectURL(new Blob([text], {type: mime}));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function updateRecordCount() {
  try {
    const count = Number(byId('recordCount').value);
    if (!Number.isInteger(count)) throw new Error('A quantidade de registros deve ser inteira.');
    if (count < 1) throw new Error('Informe pelo menos um registro.');
    if (count > 200) throw new Error('O painel aceita até 200 registros.');
    const previous = parseIni(byId('dataSource').value);
    const template = previous.get('record.0') ?? new Map();
    const records = new Map([['batch', new Map([['count', count]])]]);
    for (let recordIndex = 0; recordIndex < count; recordIndex++) {
      const record = new Map(previous.get(`record.${recordIndex}`) ?? template);
      if (!previous.has(`record.${recordIndex}`)) {
        if (record.has('sequencia')) record.set('sequencia', String(recordIndex + 1));
      }
      records.set(`record.${recordIndex}`, record);
    }
    byId('dataSource').value = serializeSections(records);
    markDirty();
  } catch (error) { setFeedback(error.message, 'error'); }
}

function applySampleToBatch() {
  try {
    const key = byId('fieldBind').value;
    if (!key) throw new Error('Informe a chave do campo nos dados.');
    const records = parseIni(byId('dataSource').value);
    for (const [sectionName, values] of records) {
      if (!sectionName.startsWith('record.')) continue;
      values.set(key, byId('sampleValue').value);
    }
    byId('dataSource').value = serializeSections(records);
    markDirty();
  } catch (error) { setFeedback(error.message, 'error'); }
}

function updateCountFromSource() {
  try { byId('recordCount').value = parseIni(byId('dataSource').value).get('batch')?.get('count') ?? ''; }
  catch { /* O gerador apresenta a mensagem completa ao aplicar os dados. */ }
}

function registerEvents() {
  byId('generatePreview').addEventListener('click', generatePreview);
  for (const button of document.querySelectorAll('[data-preset]')) {
    button.addEventListener('click', () => {
      state.layout = parseLayout(state.presets[button.dataset.preset]);
      state.selectedField = 0;
      state.rawLayoutDirty = false;
      showLayout();
      for (const preset of document.querySelectorAll('[data-preset]')) preset.classList.toggle('selected', preset === button);
      markDirty();
      generatePreview();
    });
  }
  for (const key of pageKeys) byId(key).addEventListener('input', () => {
    state.layout.page[key] = byId(key).value;
    for (const preset of document.querySelectorAll('[data-preset]')) preset.classList.remove('selected');
    syncLayoutSource(); markDirty();
  });
  byId('layoutName').addEventListener('input', () => {
    state.layout.page.name = byId('layoutName').value; syncLayoutSource(); markDirty();
  });
  for (const id of ['fieldName', ...Object.keys(fieldControls), 'fieldBold', 'fieldRequired']) {
    byId(id).addEventListener('input', updateField);
  }
  byId('fieldType').addEventListener('change', () => {
    const masks = {text: '{value}', date: 'dd/mm/yyyy', decimal: '#,##0.00', integer: '000'};
    byId('fieldMask').value = masks[byId('fieldType').value] ?? '';
    updateField();
  });
  byId('selectedField').addEventListener('change', () => selectField(Number(byId('selectedField').value)));
  byId('fieldBind').addEventListener('change', () => { byId('sampleValue').value = readSampleValue(); });
  byId('addField').addEventListener('click', () => {
    if (state.layout.fields.length >= 64) { setFeedback('O layout aceita até 64 campos.', 'error'); return; }
    let suffix = state.layout.fields.length + 1;
    while (state.layout.fields.some(field => field.name === `novoCampo${suffix}`)) suffix++;
    state.layout.fields.push({name: `novoCampo${suffix}`, values: {source: 'fixed', type: 'text', value: 'Novo texto',
      xMm: '1', yMm: '1', widthMm: 'auto', heightMm: '3', fontFamily: 'Arial', fontSizePt: '6', align: 'left'}});
    state.selectedField = state.layout.fields.length - 1;
    refreshFieldList(); selectField(state.selectedField); syncLayoutSource(); markDirty();
  });
  byId('removeField').addEventListener('click', () => {
    if (state.layout.fields.length <= 1) return;
    state.layout.fields.splice(state.selectedField, 1);
    state.selectedField = Math.min(state.selectedField, state.layout.fields.length - 1);
    refreshFieldList(); selectField(state.selectedField); syncLayoutSource(); markDirty();
  });
  byId('applySample').addEventListener('click', applySampleToBatch);
  byId('sampleValue').addEventListener('change', applySampleToBatch);
  byId('sampleValue').addEventListener('keydown', event => { if (event.key === 'Enter') applySampleToBatch(); });
  byId('resizeBatch').addEventListener('click', updateRecordCount);
  byId('recordCount').addEventListener('change', updateRecordCount);
  for (const id of ['dpi', 'startIndex']) byId(id).addEventListener('input', markDirty);
  byId('decimalSeparator').addEventListener('change', () => {
    const separator = byId('decimalSeparator').value;
    state.layout.format.decimalSeparator = separator;
    state.layout.format.thousandSeparator = separator === ',' ? '.' : ',';
    syncLayoutSource(); markDirty();
  });
  byId('showGuides').addEventListener('change', () => byId('pages').classList.toggle('hideGuides', !byId('showGuides').checked));
  byId('zoom').addEventListener('change', updateZoom);
  byId('pages').addEventListener('click', event => {
    const text = event.target.closest('text[data-field]');
    if (!text) return;
    const fieldIndex = state.layout.fields.findIndex(field => field.name === text.dataset.field);
    if (fieldIndex < 0) return;
    selectField(fieldIndex);
    byId('selectedField').scrollIntoView({behavior: 'smooth', block: 'center'});
  });
  byId('layoutSource').addEventListener('input', () => { state.rawLayoutDirty = true; markDirty(); });
  byId('dataSource').addEventListener('input', () => { updateCountFromSource(); markDirty(); });
  byId('applyLayoutSource').addEventListener('click', () => { state.rawLayoutDirty = true; markDirty(); generatePreview(); });
  byId('applyDataSource').addEventListener('click', () => { updateCountFromSource(); byId('sampleValue').value = readSampleValue(); generatePreview(); });
  byId('downloadLayout').addEventListener('click', () => {
    try { downloadFile('etiquetas.lay', state.rawLayoutDirty ? byId('layoutSource').value : layoutText()); }
    catch (error) { setFeedback(error.message, 'error'); }
  });
  byId('downloadData').addEventListener('click', () => downloadFile('dados.ini', byId('dataSource').value));
  byId('downloadSvg').addEventListener('click', () => {
    if (!state.preview) return;
    downloadFile('pagina-001.svg', state.preview.pages[0], 'image/svg+xml;charset=utf-8');
  });
  byId('printPreview').addEventListener('click', () => { if (!inspectText()) return; window.print(); });
  byId('importLayout').addEventListener('click', () => byId('layoutFile').click());
  byId('layoutFile').addEventListener('change', async () => {
    const file = byId('layoutFile').files[0];
    if (!file) return;
    try {
      if (file.size > 131072) throw new Error('O layout excede 128 KiB.');
      byId('layoutSource').value = await file.text();
      state.rawLayoutDirty = true;
      applyRawLayout(); markDirty(); await generatePreview();
    } catch (error) { setFeedback(error.message, 'error'); }
    finally { byId('layoutFile').value = ''; }
  });
}

async function initialize() {
  byId('generatePreview').disabled = true;
  try {
    const response = await fetch('/api/config');
    if (!response.ok) throw new Error('Não foi possível carregar o painel.');
    const configuration = await response.json();
    state.session = configuration.session;
    state.presets = configuration.presets;
    state.layout = parseLayout(configuration.presets['6']);
    byId('dataSource').value = configuration.data;
    updateCountFromSource();
    showLayout();
    registerEvents();
    byId('connection').textContent = 'Gerador conectado';
    byId('generatePreview').disabled = false;
    await generatePreview();
  } catch (error) {
    byId('connection').textContent = 'Sem conexão';
    setFeedback(error.message, 'error');
  }
}

initialize();
