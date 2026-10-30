# Formato `.lay`, versão 1

Arquivo INI em UTF-8. Números de configuração usam ponto decimal. Comentários devem ocupar uma linha própria, iniciada por `;`. Valores não usam aspas. Não repita nomes de seções ou chaves: a versão 1 usa a semântica de leitura de `TMemIniFile`, sem uma verificação adicional de duplicatas.

No painel visual, a importação/edição adiciona uma verificação de seções e chaves duplicadas. Os controles de edição geram esse mesmo formato; o conteúdo pode ser visto em **Ver e editar os arquivos** e salvo com **Baixar .lay**. Comentários não são preservados ao reserializar pelo formulário.

Seções/chaves desconhecidas e versões diferentes de 1 são rejeitadas. Os nomes de campos começam com `field.`; mantenha a grafia dos exemplos. Valores como `text`, `fixed` e `center` são sensíveis a maiúsculas/minúsculas. O vínculo entre `bind` e a chave do registro também é sensível à grafia.

## `[layout]`

Todas as chaves são obrigatórias:

| Chave | Significado |
| --- | --- |
| `version` | `1` |
| `name` | Nome apresentado na prévia |
| `pageWidthMm`, `pageHeightMm` | Dimensões físicas da página |
| `labelWidthMm`, `labelHeightMm` | Dimensões de cada etiqueta |
| `columns` | Quantidade de colunas, de 1 a 1000 |
| `columnGapMm`, `rowGapMm` | Distância livre entre etiquetas |
| `marginLeftMm`, `marginTopMm`, `marginRightMm`, `marginBottomMm` | Margens em relação à página física |

Dimensões precisam ser positivas. Margens e intervalos podem ser zero. Valores numéricos de configuração são limitados a 10.000, além das verificações de encaixe. A quantidade de linhas é calculada; não há uma chave `rows`.

## `[format]`

As duas chaves são obrigatórias, com um caractere cada e valores diferentes:

```ini
[format]
decimalSeparator=,
thousandSeparator=.
```

Use separadores ASCII. Eles afetam a **saída**; valores decimais de entrada sempre usam ponto, sem agrupamento.

## `[field.nome]`

Até 64 campos. A ordem de declaração é a ordem de desenho. Todos os campos se repetem em cada etiqueta; os dados variáveis mudam conforme o registro.

| Chave | Valores e padrão |
| --- | --- |
| `source` | Obrigatória: `fixed` ou `variable` |
| `type` | Obrigatória: `text`, `date`, `decimal` ou `integer` |
| `value` | Obrigatória para `fixed`; não pode coexistir com `bind` |
| `bind` | Obrigatória para `variable`; nome da chave nos dados |
| `mask` | Opcional; significado conforme o tipo |
| `prefix`, `suffix` | Opcionais; aplicados depois da máscara |
| `required` | `true` por padrão; `false` omite o campo se o valor estiver ausente ou vazio |
| `xMm`, `yMm` | Obrigatórias; origem local à etiqueta |
| `widthMm` | Obrigatória: número positivo ou `auto` |
| `heightMm` | Obrigatória: número positivo |
| `fontFamily` | `Arial` por padrão; depende da fonte disponível no destino |
| `fontSizePt` | Obrigatória; positiva e até 72 pontos |
| `bold` | `false` por padrão; aceita somente `true`/`false` |
| `align` | `left` por padrão; aceita `left`, `center`, `right` |

`widthMm=auto` calcula `labelWidthMm - xMm - 1`: reserva 1 mm no lado direito. Não ajusta a fonte nem quebra o texto. O retângulo inteiro do campo deve caber na etiqueta. Uma origem pode ser zero, mas largura e altura devem permanecer positivas depois da conversão para pixels.

### Tipos e máscaras

| Tipo | Entrada | Máscara | Exemplo |
| --- | --- | --- | --- |
| `text` | Texto UTF-8 | Vazia preserva o valor; caso informada, deve conter exatamente um `{value}` | `mask=L:{value}` + `L001` → `L:L001` |
| `date` | Exatamente `YYYY-MM-DD`, com data válida | `FormatDateTime`; padrão `dd/mm/yyyy` | `dd/mm/yy` + `2028-02-29` → `29/02/28` |
| `decimal` | Dígitos com `-` opcional, ponto opcional e até 4 casas | `FormatCurr`; padrão `0.00` | `#,##0.00` + `1250.50` → `1.250,50` |
| `integer` | Dígitos decimais com `-` opcional, dentro de `Int64` | Vazia ou apenas zeros para preenchimento mínimo | `000` + `7` → `007` |

Para datas, o separador de saída é `/`. Para decimais, `Currency` preserva até quatro casas; uma máscara com menos casas pode arredondar a apresentação. Entrada com mais de quatro casas é rejeitada, sem arredondamento silencioso. Não são aceitos notação exponencial, `NaN`, separador de milhar ou vírgula decimal na entrada. Inteiros não passam por ponto flutuante, preservando valores de 64 bits.

As máscaras de data e decimal usam a RTL, sem uma linguagem adicional de validação: confira seu resultado com valores representativos. `prefix` e `suffix` são texto literal. Não há avaliação de código.

## Dados do demonstrador

O `.lay` não contém os registros variáveis. O exemplo os carrega de outro INI:

```ini
[batch]
count=1

[record.0]
descricao=Solução 01
lote=L001
validade=2028-02-29
valor=1250.50
sequencia=1
```

São aceitos de 1 a 10.000 registros, numerados continuamente a partir de zero. Chaves extras nos registros são permitidas. A API do núcleo também pode receber registros construídos em memória; o leitor INI é apenas a entrada do demonstrador.

## Limites da prévia

O modo sem impressora simula toda a página como imprimível. O adaptador VCL recebe do driver a região realmente disponível. O plano valida geometria e conteúdo tipado; o destino mede a tipografia. A verificação de fontes no navegador acontece ao abrir o HTML e ao usar seu botão de impressão. Ela não acompanha automaticamente os SVGs avulsos e não substitui a medição no driver.
