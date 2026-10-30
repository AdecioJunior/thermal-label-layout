# Thermal Label Layout

Repositório público: [AdecioJunior/thermal-label-layout](https://github.com/AdecioJunior/thermal-label-layout).

Um demonstrador em Object Pascal para separar **layout, dados, geometria e saída** na impressão de etiquetas. O arquivo `.lay` descreve os campos; o programa recebe um lote de registros, calcula as posições e gera uma prévia sem precisar de impressora física.

Inclui um painel visual para criar e experimentar arquivos `.lay`: etiquetas com 3, 5 e 6 colunas, textos fixos e variáveis, datas, valores, máscaras e reaproveitamento de uma página parcialmente utilizada. Os dados dos exemplos são fictícios. Este código foi escrito para demonstração técnica; não contém código de sistemas hospitalares ou de antigos empregadores.

Leia o artigo técnico: [TPrinter: tão antigo quanto funcional](docs/artigo-tprinter.md).

## Executar sem impressora

### Pela IDE Lazarus

Abra **`labelDemo.lpi`**, na raiz desta pasta. O projeto contém `labelDemo.lpr` e as units de `src`, com caminhos relativos, saída em `build/` e um modo Debug. Usa apenas as bibliotecas RTL/FCL do Free Pascal; não depende da LCL nem de componentes instalados.

Pressione **F9** para compilar e executar. O programa abre o navegador em **http://127.0.0.1:8767/**, com um exemplo já preenchido. Se o navegador não abrir, acesse esse endereço manualmente. O processo permanece em execução para atender ao painel; encerre usando Stop na IDE ou Ctrl+C no terminal. Fechar a aba do navegador não encerra o programa.

Se você estava com a versão anterior aberta na IDE, reabra o `.lpi` para carregar os parâmetros novos. Em **Run → Run Parameters**, o argumento para abrir o painel é **`--panel`**. Sem argumentos, o executável também abre o painel; pode ser iniciado com duplo clique em `build/label-demo.exe`.

### Experimentar no painel

1. Escolha um modelo de **3, 5 ou 6 colunas**.
2. Ajuste a página, o tamanho das etiquetas, as margens e os intervalos.
3. Selecione um campo para editar origem fixa/variável, tipo, máscara, posição e fonte. Clicar em um texto na prévia também seleciona seu campo.
4. Para campos variáveis, altere o **valor de teste**. Ele é aplicado ao lote ao sair do campo ou clicar em **Aplicar ao lote**.
5. Clique em **Gerar prévia**. Dados inválidos e etiquetas que não cabem apresentam uma mensagem. Textos que excedem os campos ficam em vermelho e bloqueiam o botão de impressão.
6. Use **Baixar .lay** para salvar o layout. **Abrir .lay** permite carregar outro arquivo. Os dados podem ser editados e baixados na seção **Ver e editar os arquivos**.

O painel oferece zoom, guias e impressão/PDF de todas as páginas. **Baixar SVG** salva a primeira página; os SVGs de todas as páginas e uma prévia HTML independente ficam em `output/panel/8767/preview/`. O último `.lay` e os dados enviados ficam em `output/panel/8767/`. Esses arquivos são sobrescritos ao gerar outra prévia: baixe o que quiser manter. Cada porta tem sua própria pasta de saída. Os arquivos originais de `examples/` não são modificados. Recarregar o painel volta ao exemplo inicial.

O formulário preenche o INI; o botão de prévia envia `.lay` + dados para **o mesmo núcleo Pascal usado na CLI**. O JavaScript não implementa uma segunda geometria nem formata os valores de impressão. Sua função é editar os arquivos, mostrar os SVGs retornados e medir as fontes disponíveis no navegador. O HTML, o CSS e o JavaScript do painel ficam separados em `web/`.

O servidor atende somente em `127.0.0.1`, sem serviços externos. O painel limita cada prévia a 200 registros, 50 páginas, 500 mm por dimensão de página e DPI entre 72 e 600. A CLI mantém os limites gerais do núcleo. O editor rejeita seções/chaves duplicadas para evitar ambiguidades.

Também é possível compilar o projeto pelo terminal:

```sh
lazbuild labelDemo.lpi
```

Para iniciar sem a IDE, na raiz do projeto:

```powershell
./build/label-demo.exe --panel
```

Outra porta: `--panel 8768`. Para iniciar sem abrir o navegador automaticamente: `--panel 8768 --no-browser`.

### Pelo compilador Free Pascal

Requisito: Free Pascal 3.2.2 com as unidades FCL (`IniFiles`, JSON, HTTP e sockets). Não depende de bibliotecas de terceiros.

Windows, a partir desta pasta:

```powershell
./scripts/verify.ps1 -compilerPath 'C:/FPC/3.2.2/bin/i386-Win32/fpc.exe'
Start-Process './output/columns-6/preview.html'
```

Se `fpc` já estiver no `PATH`, basta `./scripts/verify.ps1`.

Linux:

```sh
sudo apt-get install fp-compiler fp-units-fcl fp-units-net
sh scripts/verify.sh
```

O script compila o programa e os testes, executa as verificações e gera os três exemplos. Abra `output/columns-3/preview.html`, `output/columns-5/preview.html` ou `output/columns-6/preview.html` no navegador. Cada saída contém também os SVGs individuais das páginas.

Para executar um layout individual:

```powershell
./build/label-demo.exe examples/labels-6.lay examples/sample-data.ini output/meu-teste 203 2
```

Argumentos: `layout.lay dados.ini pastaSaida [dpi=203] [indiceInicial=0]`. O índice é zero-based e vale somente para a primeira página: `2` deixa as duas primeiras posições sem impressão. As páginas seguintes começam na posição zero. A pasta de saída deve ser específica para o lote; arquivos de execuções anteriores não são removidos.

A prévia permite ocultar as guias e abrir a impressão do navegador para salvar PDF. O botão verifica se os textos cabem nos campos usando as fontes disponíveis naquele navegador. Na impressão/PDF, use tamanho real, escala 100%, sem cabeçalhos e sem margens adicionais. O mecanismo de impressão do navegador pode alterar o tamanho do papel: confira as dimensões do PDF resultante antes de usá-lo como referência física.

## Exemplo de campo

```ini
[field.validade]
source=variable
type=date
bind=validade
mask=dd/mm/yy
prefix=Dt:
xMm=1
yMm=13
widthMm=auto
heightMm=3
fontSizePt=5.5
```

Com `validade=2028-02-29`, o campo produz `Dt:29/02/28`. Um campo fixo usa `source=fixed` e `value=AMOSTRA`, em vez de `bind`.

Consulte a [especificação do `.lay`](docs/layout-format.md) e os [exemplos completos](examples/labels-6.lay).

## Área de impressão e salto de colunas

O layout usa milímetros, com origem no canto superior esquerdo **físico** da página. Cada campo tem coordenadas locais à sua etiqueta. Para uma posição `indiceNaPagina`:

```pascal
indiceColuna := indiceNaPagina mod quantidadeColunas;
indiceLinha := indiceNaPagina div quantidadeColunas;

posicaoHorizontalMm := margemEsquerdaMm +
  indiceColuna * (larguraEtiquetaMm + espacoEntreColunasMm);
posicaoVerticalMm := margemSuperiorMm +
  indiceLinha * (alturaEtiquetaMm + espacoEntreLinhasMm);
```

O passo horizontal é largura da etiqueta mais o intervalo entre etiquetas. O intervalo final não é contado como uma coluna extra. O número de linhas considera altura da página, margens, altura da etiqueta e intervalo vertical.

Cada borda é convertida diretamente a partir de sua posição absoluta, evitando acumular erros ao somar larguras já arredondadas:

```text
xPixels = Round(xMm * dpiX / 25.4) - physicalOffsetX
yPixels = Round(yMm * dpiY / 25.4) - physicalOffsetY
```

O deslocamento físico do driver é subtraído uma única vez. DPI horizontal e vertical são independentes. No adaptador VCL, `PHYSICALWIDTH`/`PHYSICALHEIGHT` descrevem a página física; `HORZRES`/`VERTRES` descrevem a região imprimível. O núcleo rejeita etiquetas que ultrapassem essa região, inclusive quando seu conteúdo ocupar apenas uma parte da etiqueta.

Nos exemplos, a página mede 104 × 60 mm e comporta duas linhas. Com 13 registros e duas posições iniciais usadas:

| Colunas | Etiqueta | Capacidade por página | Páginas |
| --- | --- | --- | --- |
| 3 | 32 × 24 mm | 6 | 3 |
| 5 | 18 × 24 mm | 10 | 2 |
| 6 | 15 × 24 mm | 12 | 2 |

Alterar o tamanho da etiqueta não garante que o mesmo conteúdo continuará legível: o cálculo geométrico e a medição da fonte são verificações distintas.

## Organização do código

| Arquivo | Responsabilidade |
| --- | --- |
| `labelDemo.lpi` / `labelDemo.lpr` | Projeto Lazarus e entrada do demonstrador console |
| `src/labelPanel.pas` | Servidor HTTP local e ponte entre o painel e o núcleo |
| `web/index.html`, `web/panel.css`, `web/panel.js` | Interface de edição, arquivos e visualização |
| `src/labelTypes.pas` | Tipos do layout, métricas e plano de impressão |
| `src/labelLayout.pas` | Leitura e validação do `.lay` |
| `src/labelData.pas` | Leitura dos registros de exemplo |
| `src/labelFormatting.pas` | Tipos, valores canônicos e máscaras |
| `src/labelGeometry.pas` | Grade, margens, DPI e área imprimível |
| `src/labelPlan.pas` | Resolução de todo o lote e paginação |
| `src/labelSvg.pas` | SVG e prévia HTML independente de impressora |
| `adapters/vcl/labelVcl.pas` | Saída para `TBitmap.Canvas` e `TPrinter.Canvas` |

O plano resolve e valida todos os registros antes de exportar ou desenhar. Um valor inválido no último registro impede o início da renderização do lote. Falhas de disco, driver ou dispositivo durante a saída não tornam a operação transacional.

As validações retornam no primeiro erro, com guard clauses. A solução usa nomes descritivos em camelCase para variáveis, funções e propriedades de configuração.

## Adaptador Delphi / TPrinter

O adaptador usa as APIs VCL do Windows. Compile `adapters/vcl/demoVcl.dpr` em um Delphi com namespaces VCL e suporte a `Exit(valor)`, adicionando `src` e `adapters/vcl` ao caminho de units. Exemplo no terminal configurado pelo Delphi:

```powershell
dcc32 '-Usrc;adapters/vcl' '-Ebuild' '-N0build' adapters/vcl/demoVcl.dpr
```

Prévia em BMP pelo Canvas do Windows, sem selecionar impressora:

```powershell
./build/demoVcl.exe preview examples/labels-6.lay examples/sample-data.ini output/vcl 203 2
```

Impressão explícita:

```powershell
./build/demoVcl.exe print examples/labels-6.lay examples/sample-data.ini 'Nome exato da impressora' 2
```

Configure previamente no driver uma página de 104 × 60 mm, na orientação correspondente ao layout. O exemplo não altera `DEVMODE` nem cria formulários personalizados. Se o driver entregar outra dimensão física, o plano é rejeitado. Em uma bobina, a definição do comprimento de página, sensores, avanço e calibração continua sendo responsabilidade da configuração do dispositivo.

O adaptador abre o documento, lê as métricas do contexto ativo e mede todos os textos no Canvas de destino antes de desenhar a primeira página. Usa `BeginDoc`, `NewPage`, `EndDoc` e `Abort` em caso de erro. O bitmap ajuda a conferir o caminho GDI, mas as métricas das fontes podem diferir das fornecidas pelo driver da impressora.

Essa abordagem não exige emitir PPLA/PPLB diretamente: o Windows e o driver traduzem os desenhos. A compatibilidade continua dependendo de um driver funcional, suporte ao papel e calibração correta.

## O que foi verificado

Execução local em Windows com Free Pascal 3.2.2: **10 grupos e 64 verificações aprovadas**. Cobertura de grades, salto de posições, paginação, independência entre registros, arredondamento em 203/300/600 DPI, DPI diferente por eixo, offsets físicos, formatos explícitos, datas bissextas, precisão de `Int64`/`Currency`, entradas inválidas e escape de XML.

O projeto `labelDemo.lpi` também foi compilado com `lazbuild` do Lazarus 4.6 para Windows de 32 e 64 bits, com execução do demonstrador. Os caminhos do compilador usados na máquina de validação não são gravados no projeto: a IDE usa o Free Pascal configurado na instalação de cada pessoa.

A prévia de seis colunas foi conferida no navegador, com todos os textos dentro das áreas declaradas. A rotina de medição também identifica texto excedente e bloqueia o botão de impressão. Os SVGs individuais contêm as guias; a página HTML as oculta ao imprimir.

O teste de integração `tests/panelSmoke.py` executa o servidor e a CLI, compara seus SVGs nos três modelos e verifica UTF-8, máscaras, rejeições e rotas. Foram **34 verificações aprovadas**, além das 64 do núcleo. Ele usa Python 3, apenas com a biblioteca padrão, como ferramenta de teste opcional:

```sh
python tests/panelSmoke.py
```

Na interface foram conferidas troca de modelos, alteração de valor/máscara, importação de `.lay`, grade inválida, data inválida e bloqueio de impressão por texto excedente. O SVG reserva 0,3 mm nas extremidades horizontais do campo ao alinhar à esquerda/direita, para acomodar o avanço lateral dos glifos. A tinta continua sendo medida em relação ao retângulo completo do campo.

**O adaptador VCL foi fornecido como código-fonte e ainda não foi compilado com Delphi nem testado em impressora física.** O workflow Linux está preparado em `.github/workflows/verify.yml`; a execução local verificada foi em Windows.

Não há suporte nesta versão a código de barras, QR Code, imagens, quebra de linha, ajuste automático de fonte, expressões ou scripts no layout. Tipografia e densidade efetiva de uma etiqueta pequena precisam ser confirmadas no material final.

## Publicar como repositório separado

Esta pasta é independente do projeto vizinho. Não contém configuração de remoto nem credenciais. `build/` e `output/` estão no `.gitignore`; os resultados são reproduzidos pelos scripts. Para iniciar seu repositório, execute **dentro desta pasta**:

```sh
git init
git add .
git commit -m "Add typed label layouts and Pascal printing demo"
```

Depois, associe o remoto público que você criar no GitHub. Nenhum commit ou envio é feito pelos scripts deste projeto.

## Referências técnicas

- [TMemIniFile — Free Pascal](https://www.freepascal.org/docs-html/current/fcl/inifiles/tmeminifile-3.html)
- [TFormatSettings — Free Pascal](https://www.freepascal.org/docs-html/rtl/sysutils/tformatsettings.html)
- [Impressão em aplicações VCL — Embarcadero](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Printing_in_VCL_Applications)
- [TPrinter.Canvas — Embarcadero](https://docwiki.embarcadero.com/Libraries/Sydney/en/Vcl.Printers.TPrinter.Canvas)
- [GetDeviceCaps — Microsoft](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getdevicecaps)
- [TFPHTTPServer — Free Pascal](https://www.freepascal.org/daily/packages/fcl-web/fphttpserver/tfphttpserver.html)
