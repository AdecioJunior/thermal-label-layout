program demoVcl;

{$APPTYPE CONSOLE}

uses System.SysUtils, Vcl.Printers, labelTypes, labelLayout, labelData, labelVcl;

procedure executar;
var layout: TDocumentoLayout; dados: TRegistrosDados;
  modo, destino: string; resolucaoDpi, indiceInicial, indiceImpressora: Integer;
begin
    if ParamCount < 4 then raise ELabelError.Create(
      'Uso: demoVcl preview layout.lay dados.ini pasta-saida [dpi=203] [indiceInicial=0]' + sLineBreak +
      ' ou: demoVcl print layout.lay dados.ini "Nome exato da impressora" [indiceInicial=0]');
    modo := ParamStr(1);
    if modo <> 'preview' then
      if modo <> 'print' then raise ELabelError.Create('Modo deve ser preview ou print.');
    layout := carregarLayout(ParamStr(2));
    dados := carregarDados(ParamStr(3));
    destino := ParamStr(4);
    indiceInicial := 0;
    if modo = 'preview' then
    begin
      if ParamCount > 6 then raise ELabelError.Create('Argumentos em excesso.');
      resolucaoDpi := 203;
      if ParamCount >= 5 then
        if not TryStrToInt(ParamStr(5), resolucaoDpi) then raise ELabelError.Create('DPI invalido.');
      if ParamCount >= 6 then
        if not TryStrToInt(ParamStr(6), indiceInicial) then raise ELabelError.Create('Indice inicial invalido.');
      exportarBitmaps(layout, dados, destino, resolucaoDpi, indiceInicial);
      WriteLn('Previa bitmap gerada. Nenhum trabalho foi enviado a impressora.');
      Exit;
    end;
    if ParamCount > 5 then raise ELabelError.Create('Argumentos em excesso.');
    if ParamCount = 5 then
      if not TryStrToInt(ParamStr(5), indiceInicial) then raise ELabelError.Create('Indice inicial invalido.');
    indiceImpressora := Printer.Printers.IndexOf(destino);
    if indiceImpressora < 0 then raise ELabelError.Create('Impressora nao encontrada: ' + destino);
    Printer.PrinterIndex := indiceImpressora;
    imprimirLayout(Printer, layout, dados, indiceInicial);
    WriteLn('Trabalho entregue ao sistema de impressao do Windows.');
end;

begin
  try
    executar;
  except
    on erro: Exception do
    begin
      WriteLn(ErrOutput, 'ERRO: ', erro.Message);
      Halt(1);
    end;
  end;
end.
