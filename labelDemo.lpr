program labelDemo;

{$IFDEF FPC}{$mode delphi}{$H+}{$codepage utf8}{$ENDIF}
{$APPTYPE CONSOLE}

uses {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, labelTypes, labelLayout, labelData, labelGeometry, labelPlan, labelSvg, labelPanel;

var layout: TDocumentoLayout; dados: TRegistrosDados; metricas: TMetricasImpressao;
  plano: TPlanoImpressao; resolucaoDpi, indiceInicial, porta: Integer;

procedure executar;
begin
    if ParamCount = 0 then begin iniciarPainel(8767, True); Exit; end;
    if ParamStr(1) = '--panel' then
    begin
      if ParamCount > 3 then raise ELabelError.Create('Uso: label-demo --panel [porta=8767] [--no-browser]');
      porta := 8767;
      if ParamCount >= 2 then
        if not TryStrToInt(ParamStr(2), porta) then raise ELabelError.Create('Porta invalida.');
      if ParamCount = 3 then
        if ParamStr(3) <> '--no-browser' then raise ELabelError.Create('Opcao desconhecida.');
      iniciarPainel(porta, ParamCount < 3);
      Exit;
    end;
    if ParamCount < 3 then
      raise ELabelError.Create('Uso: label-demo layout.lay dados.ini pasta-saida [dpi=203] [indiceInicial=0]');
    if ParamCount > 5 then raise ELabelError.Create('Argumentos em excesso.');
    resolucaoDpi := 203;
    indiceInicial := 0;
    if ParamCount >= 4 then
      if not TryStrToInt(ParamStr(4), resolucaoDpi) then raise ELabelError.Create('DPI deve ser inteiro.');
    if ParamCount >= 5 then
      if not TryStrToInt(ParamStr(5), indiceInicial) then raise ELabelError.Create('Indice inicial deve ser inteiro.');
    layout := carregarLayout(ParamStr(1));
    dados := carregarDados(ParamStr(2));
    metricas := criarMetricasSimuladas(layout.configuracao, resolucaoDpi, resolucaoDpi);
    plano := montarPlano(layout, dados, metricas, indiceInicial);
    exportarPrevia(plano, ParamStr(3));
    WriteLn('OK: ', Length(dados), ' registros; ', Length(plano.paginas), ' pagina(s).');
    WriteLn('Previa: ', IncludeTrailingPathDelimiter(ParamStr(3)), 'preview.html');
    WriteLn('Geometria simulada: ', resolucaoDpi, ' DPI, sem margens fisicas de driver.');
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);
  try
    executar;
  except
    on erro: Exception do
    begin
      WriteLn(StdErr, 'ERRO: ', erro.Message);
      Halt(1);
    end;
  end;
end.
