{ *******************************************************************************
Title: T2Ti ERP
Description: Fun��es e procedimentos do PAF;

The MIT License

Copyright: Copyright (C) 2010 T2Ti.COM

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

The author may be contacted at:
t2ti.com@gmail.com</p>

Albert Eije (T2Ti.COM)
@version 2.0
******************************************************************************* }
unit PAFUtil;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Windows, Forms, Controller, DateUtils, md5,
  VO, Inifiles, Biblioteca, ACBrPAF, strutils, UCargaPDV,
  ACBrPAF_E, ACBrPAF_P, ACBrPAF_N, ACBrPAF_R, ACBrPAFRegistros;

type
  TPAFUtil = class(TController)
  private
  public
    class procedure GerarRegistrosPAF(pDataInicio: TDateTime; pDataFim: TDateTime; pEstoqueTotalOuParcial: String; pEstoqueCodigoOuNome: String = ''; pEstoqueCriterioUm: String = ''; pEstoqueCriterioDois: String = ''; pDataMovimento: String = '');
    class procedure GerarRegistroU;
    class procedure GerarRegistroA2;
    class procedure GerarRegistroP2;
    class procedure GerarRegistroE2;
    class procedure GerarRegistroE3;
    class procedure GerarRegistrosDAV;
    class procedure GerarRegistrosR;

    class procedure IdentificacaoPafEcf;
    class procedure ParametrodeConfiguracao;

    class procedure GravarR02R03;
    class procedure Gravar60M60A;
    class procedure GravarR06(Simbolo: String);

    class function ECFAutorizado: Boolean;
    class function ConfereGT: Boolean;
    class procedure AtualizaGT;
    class procedure GravarIdUltimaVenda;
    class function RecuperarIdUltimaVenda: String;
    class function AtualizarEstoque(pForcarAtualizacao: Boolean): Boolean;

    class function GeraMD5: String;
  end;

implementation

uses
  UDataModule,

  R01VO, R02VO, R03VO, EcfVendaCabecalhoVO, EcfVendaDetalheVO, R06VO, R07VO,
  ViewTotalPagamentoDataVO, DavCabecalhoVO, DAVDetalheVO, EcfTotalTipoPagamentoVO,
  EcfImpressoraVO, EcfProdutoVO, Sintegra60MVO, Sintegra60AVO, EcfE3VO,

  ProdutoController, ViewTotalPagamentoDataController, EcfTotalTipoPagamentoController,
  LogssController, EcfE3Controller, R02Controller, R06Controller, VendaController,
  Sintegra60MController;

var
  ValorHashRegistro, NomeArquivo, DataInicio, DataFim, Filtro: String;


{$REGION 'Gera��o Arquivo Registros PAF'}
class procedure TPAFUtil.GerarRegistrosPAF(pDataInicio: TDateTime; pDataFim: TDateTime; pEstoqueTotalOuParcial: String; pEstoqueCodigoOuNome: String; pEstoqueCriterioUm: String; pEstoqueCriterioDois: String; pDataMovimento: String);
begin
  try
    try
      FormatSettings.DecimalSeparator := '.';

      DataInicio := DataParaTexto(pDataInicio);
      DataFim := DataParaTexto(pDataFim);

      // U1 - Identifica��o do Estabelecimento Usu�rio do PAF-ECF
      GerarRegistroU;

      // A2 - Total Di�rio de Meios de Pagamento
      GerarRegistroA2;

      // P2 - Rela��o das Mercadorias e Servi�os
      GerarRegistroP2;

      // E2 - Rela��o das Mercadorias em Estoque
      if pEstoqueTotalOuParcial = 'T' then
        Filtro := 'ID>0'
      else
      begin
        if pEstoqueCodigoOuNome = 'C' then
          Filtro := 'ID between ' + pEstoqueCriterioUm + ' and ' + pEstoqueCriterioDois
        else if pEstoqueCodigoOuNome = 'N' then
        begin
          pEstoqueCriterioUm := '%' + Trim(pEstoqueCriterioUm) + '%';
          pEstoqueCriterioDois := '%' + Trim(pEstoqueCriterioDois) + '%';
          Filtro := 'NOME LIKE ' + QuotedStr(pEstoqueCriterioUm) + ' or ' + 'NOME LIKE ' + QuotedStr(pEstoqueCriterioDois);
        end;
      end;
      GerarRegistroE2;

      // E3 - Identifica��o do ECF que Emitiu o Documento Base para a Atualiza��o do Estoque
      GerarRegistroE3;


      // D2 - Rela��o dos DAV Emitidos
      // D3 - Detalhe do DAV
      GerarRegistrosDAV;

      // R01 a R07
      GerarRegistrosR;

      (*
        O arquivo a que se refere o item 5 dever� ser denominado no formato CCCCCCNNNNNNNNNNNNNNDDMMAAAA.txt, sendo:
        a) �CCCCCC� o C�digo Nacional de Identifica��o de ECF relativo ao ECF a que se refere o movimento informado;
        b) �NNNNNNNNNNNNNN� os 14 (quatorze) �ltimos d�gitos do n�mero de fabrica��o do ECF;
        c) �DDMMAAAA� a data (dia/m�s/ano) do movimento informado no arquivo.
      *)
      NomeArquivo := Sessao.Configuracao.EcfImpressoraVO.Codigo;

      if length(Sessao.Configuracao.EcfImpressoraVO.Serie) > 14 then
        NomeArquivo := NomeArquivo + RightStr(Sessao.Configuracao.EcfImpressoraVO.Serie, 14)
      else
        NomeArquivo := NomeArquivo + StringOfChar('0', 14 - length(Sessao.Configuracao.EcfImpressoraVO.Serie)) + Sessao.Configuracao.EcfImpressoraVO.Serie;

      if pDataMovimento = '' then
        NomeArquivo := NomeArquivo + FormatDateTime('ddmmyyyy', Now)
      else
        NomeArquivo := NomeArquivo + FormatDateTime('ddmmyyyy', StrToDateTime(pDataMovimento));

      NomeArquivo := NomeArquivo + '.txt';

      FDataModule.ACBrPAF.SaveFileTXT_RegistrosPAF(NomeArquivo);
      Application.MessageBox(PChar('Arquivo armazenado em: ' + NomeArquivo), 'Informa��o do Sistema', MB_OK + MB_ICONINFORMATION);
    except
      on E: Exception do
        Application.MessageBox(PChar('Ocorreu um erro durante a gera��o do arquivo. Informe a mensagem ao Administrador do sistema.' + #13 + #13 + E.Message), 'Erro do sistema', MB_OK + MB_ICONERROR);
    end;
  finally
    FormatSettings.DecimalSeparator := ',';
  end;
end;

class procedure TPAFUtil.GerarRegistroU;
var
  Retorno: Boolean;
begin
  with FDataModule.ACBrPAF.PAF_U.RegistroU1 do
  begin
    Retorno := TLogssController.VerificarQuantidades;
    InclusaoExclusao := Not Retorno;

    // ALTERAR - CONSULTAR DAV NO BANCO DA RETAGUARDA

    CNPJ := Sessao.Configuracao.EcfEmpresaVO.CNPJ;
    IE := Sessao.Configuracao.EcfEmpresaVO.InscricaoEstadual;
    IM := Sessao.Configuracao.EcfEmpresaVO.InscricaoMunicipal;
    RAZAOSOCIAL := Sessao.Configuracao.EcfEmpresaVO.RAZAOSOCIAL;
  end;
end;

class procedure TPAFUtil.GerarRegistroA2;
var
  ListaA2: TListaViewTotalPagamentoDataVO;
  ListaPagamentos: TListaEcfTotalTipoPagamentoVO;
  I, J: Integer;
begin
  try
    Filtro := '(DATA_VENDA between ' + QuotedStr(DataInicio) + ' and ' + QuotedStr(DataFim) + ')';
    ListaA2 := TViewTotalPagamentoDataController.ConsultaLista(Filtro);

    if Assigned(ListaA2) then
    begin
      FDataModule.ACBrPAF.PAF_A.RegistroA2.Clear;
      for I := 0 to ListaA2.Count - 1 do
      begin
        with FDataModule.ACBrPAF.PAF_A.RegistroA2.New do
        begin
          // Consulta todos os pagamentos desse tipo para observar se houve alguma altera��o e se houver invalida o registro
          Filtro := 'DATA_VENDA = ' + QuotedStr(DataParaTexto(ListaA2[I].DataVenda)) + ' AND ID_ECF_TIPO_PAGAMENTO = ' + IntToStr(ListaA2[I].IdTipoPagamento);
          ListaPagamentos := TEcfTotalTipoPagamentoController.ConsultaLista(Filtro);

          for J := 0 to ListaPagamentos.Count - 1 do
          begin
            ValorHashRegistro := TEcfTotalTipoPagamentoVO(ListaPagamentos.Items[J]).HashRegistro;
            TEcfTotalTipoPagamentoVO(ListaPagamentos.Items[J]).Id := 0;
            TEcfTotalTipoPagamentoVO(ListaPagamentos.Items[J]).HashRegistro := '0';
            if MD5Print(MD5String(TEcfTotalTipoPagamentoVO(ListaPagamentos.Items[J]).ToJSONString)) <> ValorHashRegistro then
              RegistroValido := False;
          end;

          DT := ListaA2[I].DataVenda;
          MEIO_PGTO := ListaA2[I].Descricao;
          TIPO_DOC := '1'; // 1-CupomFiscal, 2-CNF, 3-Nota Fiscal
          VL := ListaA2[I].ValorApurado;
        end;
      end;
    end;
  finally
    FreeAndNil(ListaA2);
    FreeAndNil(ListaPagamentos);
  end;
end;

class procedure TPAFUtil.GerarRegistroP2;
var
  P2: TRegistroP2;
  ListaProduto: TListaEcfProdutoVO;
  I: Integer;
begin
  try
    ListaProduto := TProdutoController.ConsultaLista('ID>0');

    if Assigned(ListaProduto) then
    begin
      // registro P2
      FDataModule.ACBrPAF.PAF_P.RegistroP2.Clear;
      for I := 0 to ListaProduto.Count - 1 do
      begin
        P2 := FDataModule.ACBrPAF.PAF_P.RegistroP2.New;

        ValorHashRegistro := TEcfProdutoVO(ListaProduto.Items[I]).HashRegistro;
        TEcfProdutoVO(ListaProduto.Items[I]).HashRegistro := '0';
        if MD5Print(MD5String(TEcfProdutoVO(ListaProduto.Items[I]).ToJSONString)) <> ValorHashRegistro then
          P2.RegistroValido := False;

        P2.COD_MERC_SERV := TEcfProdutoVO(ListaProduto.Items[I]).GTIN;
        P2.DESC_MERC_SERV := TEcfProdutoVO(ListaProduto.Items[I]).DescricaoPDV;
        P2.UN_MED := TEcfProdutoVO(ListaProduto.Items[I]).UnidadeEcfProdutoVO.Sigla;
        P2.IAT := TEcfProdutoVO(ListaProduto.Items[I]).IAT;
        P2.IPPT := TEcfProdutoVO(ListaProduto.Items[I]).IPPT;
        P2.ST := TEcfProdutoVO(ListaProduto.Items[I]).PafProdutoST;
        P2.ALIQ := TEcfProdutoVO(ListaProduto.Items[I]).AliquotaICMS;
        P2.VL_UNIT := TEcfProdutoVO(ListaProduto.Items[I]).ValorVenda;
      end;
    end;

  finally
    FreeAndNil(ListaProduto);
  end;
end;

class procedure TPAFUtil.GerarRegistroE2;
var
  E2: TRegistroE2;
  ListaProduto: TListaEcfProdutoVO;
  I: Integer;
begin
  try
    ListaProduto := TProdutoController.ConsultaLista(Filtro);

    if Assigned(ListaProduto) then
    begin
      FDataModule.ACBrPAF.PAF_E.RegistroE2.Clear;
      for I := 0 to ListaProduto.Count - 1 do
      begin
        E2 := FDataModule.ACBrPAF.PAF_E.RegistroE2.New;

        ValorHashRegistro := TEcfProdutoVO(ListaProduto.Items[I]).HashRegistro;
        TEcfProdutoVO(ListaProduto.Items[I]).HashRegistro := '0';
        if MD5Print(MD5String(TEcfProdutoVO(ListaProduto.Items[I]).ToJSONString)) <> ValorHashRegistro then
          E2.RegistroValido := False;

        E2.COD_MERC := TEcfProdutoVO(ListaProduto.Items[I]).GTIN;
        E2.DESC_MERC := TEcfProdutoVO(ListaProduto.Items[I]).DescricaoPDV;
        E2.UN_MED := TEcfProdutoVO(ListaProduto.Items[I]).UnidadeEcfProdutoVO.Sigla;
        E2.QTDE_EST := TEcfProdutoVO(ListaProduto.Items[I]).QuantidadeEstoque;
      end;
    end;

  finally
    FreeAndNil(ListaProduto);
  end;
end;

class procedure TPAFUtil.GerarRegistroE3;
var
  ArquivoIni: TIniFile;
  RegistroE3: TEcfE3VO;
  DataEstoque: TDateTime;
begin
  try
    ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
    DataEstoque := ArquivoIni.ReadDate('VENDA', 'DATAESTOQUE', Date);

    RegistroE3 := TEcfE3Controller.ConsultaObjeto('DATA_ESTOQUE=' + QuotedStr(DataParaTexto(DataEstoque)));

    if Assigned(RegistroE3) then
    begin
      with FDataModule.ACBrPAF.PAF_E.RegistroE3 do
      begin
        NUM_FAB := RegistroE3.SerieEcf;
        MF_ADICIONAL := RegistroE3.MfAdicional;
        TIPO_ECF := RegistroE3.TipoEcf;
        MARCA_ECF := RegistroE3.MarcaEcf;
        MODELO_ECF := RegistroE3.ModeloEcf;
        DT_EST := RegistroE3.DataEstoque;

        ValorHashRegistro := RegistroE3.HashRegistro;
        RegistroE3.HashRegistro := '0';
        if MD5Print(MD5String(RegistroE3.ToJSONString)) <> ValorHashRegistro then
          RegistroValido := False;
      end;
    end;

  finally
    ArquivoIni.Free;
    FreeAndNil(RegistroE3);
  end;
end;

class procedure TPAFUtil.GerarRegistrosDAV;
var
  ListaDAV: TListaDavCabecalhoVO;
  I, J, K: Integer;
  Camadas: Integer;
begin
  (*
  Consultar no Brook

  try
    // Guarda Camadas. Se ocorrer algum problema, no Finally tem que setar o mesmo valor
    Camadas := Sessao.Camadas;

    Sessao.Camadas := 3;
    Filtro := 'SITUACAO = ' + QuotedStr('E');
    ListaDAV := TObjectList<TDavCabecalhoVO>(TController.BuscarLista('DAVController.TDAVController', 'ConsultaLista', [Filtro], 'GET'));
    Sessao.Camadas := 2;

    if Assigned(ListaDAV) then
    begin
      // registro D2
      FDataModule.ACBrPAF.PAF_D.RegistroD2.Clear;
      for I := 0 to ListaDAV.Count - 1 do
      begin

        with FDataModule.ACBrPAF.PAF_D.RegistroD2.New do
        begin
          ValorHashRegistro := TDavCabecalhoVO(ListaDAV.Items[I]).HashRegistro;
          TDavCabecalhoVO(ListaDAV.Items[I]).HashRegistro := '0';
          if MD5Print(MD5String(TDavCabecalhoVO(ListaDAV.Items[I]).ToJSONString)) <> ValorHashRegistro then
            RegistroValido := False;

          NUM_FAB := Sessao.Configuracao.EcfImpressoraVO.Serie;
          MF_ADICIONAL := Sessao.Configuracao.EcfImpressoraVO.MFD;
          TIPO_ECF := Sessao.Configuracao.EcfImpressoraVO.Tipo;
          MARCA_ECF := Sessao.Configuracao.EcfImpressoraVO.Marca;
          MODELO_ECF := Sessao.Configuracao.EcfImpressoraVO.Modelo;
          COO := IntToStr(TDavCabecalhoVO(ListaDAV.Items[I]).COO);
          NUMERO_ECF := TDavCabecalhoVO(ListaDAV.Items[I]).NumeroEcf;
          NOME_CLIENTE := TDavCabecalhoVO(ListaDAV.Items[I]).NomeDestinatario;
          CPF_CNPJ := TDavCabecalhoVO(ListaDAV.Items[I]).CpfCnpjDestinatario;
          NUM_DAV := TDavCabecalhoVO(ListaDAV.Items[I]).NumeroDav;
          DT_DAV := TDavCabecalhoVO(ListaDAV.Items[I]).DataEmissao;
          TIT_DAV := 'ORCAMENTO';
          VLT_DAV := TDavCabecalhoVO(ListaDAV.Items[I]).Valor;

          // registro D3
          if ListaDAV.Items[I].ListaDavDetalheVO.Count > 0 then
          begin
            for J := 0 to ListaDAV.Items[I].ListaDavDetalheVO.Count - 1 do
            begin

              with RegistroD3.New do
              begin
                ValorHashRegistro := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).HashRegistro;
                TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).HashRegistro := '0';
                if MD5Print(MD5String(TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).ToJSONString)) <> ValorHashRegistro then
                  RegistroValido := False;

                DT_INCLUSAO := TDavCabecalhoVO(ListaDAV.Items[I]).DataEmissao;
                NUM_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).Item;
                COD_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).GtinProduto;
                DESC_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).NomeProduto;
                QTDE_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).Quantidade;
                UNI_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).UnidadeProduto;
                VL_UNIT := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).ValorUnitario;
                VL_DESCTO := 0;
                VL_ACRES := 0;
                IND_CANC := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).Cancelado;
                VL_TOTAL := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).ValorTotal;
              end; // with RegistroD3.New do

              //D4 - Log altera��es DAV
              if ListaDAV.Items[I].ListaDavDetalheVO.Items[J].ListaDavDetalheAlteracaoVO.Count > 0 then
              begin
                for K := 0 to ListaDAV.Items[I].ListaDavDetalheVO.Items[J].ListaDavDetalheAlteracaoVO.Count - 1 do
                begin
                  with RegistroD4.New do
                  begin
                    NUM_DAV := TDavCabecalhoVO(ListaDAV.Items[I]).NumeroDav;
                    DT_ALT := ListaDAV.Items[I].ListaDavDetalheVO.Items[J].ListaDavDetalheAlteracaoVO.Items[K].DataAlteracao;
                    COD_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).GtinProduto;
                    DESC_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).NomeProduto;
                    QTDE_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).Quantidade;
                    UNI_ITEM := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).UnidadeProduto;
                    VL_UNIT := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).ValorUnitario;
                    VL_DESCTO := 0;
                    VL_ACRES := 0;
                    VL_TOTAL := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).ValorTotal;
                    SIT_TRIB := '';
                    ALIQ := 0;
                    IND_CANC := TDAVDetalheVO(ListaDAV.Items[I].ListaDavDetalheVO.Items[J]).Cancelado;
                    DEC_QTDE_ITEM := 2;
                    DEC_VL_UNIT := 2;
                    TIP_ALT := ListaDAV.Items[I].ListaDavDetalheVO.Items[J].ListaDavDetalheAlteracaoVO.Items[K].TipoAlteracao;

                    RegistroValido := True;
                  end;
                end;
              end;

            end; // for j := 0 to ListaDavDetalhe.Count - 1 do
          end; // if Assigned(ListaDAV) then
        end; // with FDataModule.ACBrPAF.PAF_D.RegistroD2.New do
      end; // for i := 0 to ListaDAV.Count - 1 do
    end;

  finally
    Sessao.Camadas := Camadas;
    FreeAndNil(ListaDAV);
  end;
  *)
end;

class procedure TPAFUtil.GerarRegistrosR;
var
  H, I, J: Integer;
  ListaR02: TListaR02VO;
  ListaR03: TListaR03VO;
  ListaR04: TListaEcfVendaCabecalhoVO;
  ListaR05: TListaEcfVendaDetalheVO;
  ListaR06: TListaR06VO;
  ListaR07: TListaR07VO;
  ListaR07IdR04: TListaEcfTotalTipoPagamentoVO;
begin
  try
    for H := 0 to Sessao.ListaImpressora.Count - 1 do
    begin
      // Registro R1 - Identifica��o do ECF, do Usu�rio, do PAF-ECF e da Empresa Desenvolvedora
      with FDataModule.ACBrPAF.PAF_R.RegistroR01.New do
      begin
        ValorHashRegistro := Sessao.R01.HashRegistro;
        Sessao.R01.HashRegistro := '0';
        if MD5Print(MD5String(Sessao.R01.ToJSONString)) <> ValorHashRegistro then
          RegistroValido := False;

        NUM_FAB := Sessao.R01.SerieEcf;
        MF_ADICIONAL := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).MFD;
        TIPO_ECF := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Tipo;
        MARCA_ECF := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Marca;
        MODELO_ECF := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Modelo;
        VERSAO_SB := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Versao;
        DT_INST_SB := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).DataInstalacaoSb;
        HR_INST_SB := StrToDateTime(TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).HoraInstalacaoSb);
        NUM_SEQ_ECF := TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Numero;
        CNPJ := Sessao.Configuracao.EcfEmpresaVO.CNPJ;
        IE := Sessao.Configuracao.EcfEmpresaVO.InscricaoEstadual;
        CNPJ_SH := Sessao.R01.CnpjSh;
        IE_SH := Sessao.R01.InscricaoEstadualSh;
        IM_SH := Sessao.R01.InscricaoMunicipalSh;
        NOME_SH := Sessao.R01.DenominacaoSh;
        NOME_PAF := Sessao.R01.NomePafEcf;
        VER_PAF := Sessao.R01.VersaoPafEcf;
        COD_MD5 := Sessao.R01.Md5PafEcf;
        DT_INI := TextoParaData(DataInicio);
        DT_FIN := TextoParaData(DataFim);
        ER_PAF_ECF := Sessao.R01.VersaoEr;

        // Registro R02 - Rela��o de Redu��es Z
        // Registro R03 - Detalhe da Redu��o Z
        ListaR02 := Nil;
        Filtro := 'SERIE_ECF = ' + QuotedStr(TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Serie) + ' AND (DATA_MOVIMENTO between ' + QuotedStr(DataInicio) + ' and ' + QuotedStr(DataFim) + ')';
        ListaR02 := TR02Controller.ConsultaLista(Filtro);
        if Assigned(ListaR02) then
        begin
          for I := 0 to ListaR02.Count - 1 do
          begin

            with RegistroR02.New do
            begin

              ValorHashRegistro := TR02VO(ListaR02.Items[I]).HashRegistro;
              TR02VO(ListaR02.Items[I]).Id := 0;
              TR02VO(ListaR02.Items[I]).HashRegistro := '0';
              if MD5Print(MD5String(TR02VO(ListaR02.Items[I]).ToJSONString)) <> ValorHashRegistro then
                RegistroValido := False;

              NUM_USU := TR02VO(ListaR02.Items[I]).IdOperador;
              CRZ := TR02VO(ListaR02.Items[I]).CRZ;
              COO := TR02VO(ListaR02.Items[I]).COO;
              CRO := TR02VO(ListaR02.Items[I]).CRO;
              DT_MOV := TR02VO(ListaR02.Items[I]).DataMovimento;
              DT_EMI := TR02VO(ListaR02.Items[I]).DataEmissao;
              HR_EMI := StrToDateTime(TR02VO(ListaR02.Items[I]).HoraEmissao);
              VL_VBD := TR02VO(ListaR02.Items[I]).VendaBruta;
              PAR_ECF := '';

              // Registro R03 - FILHO
              ListaR03 := TR02VO(ListaR02.Items[I]).ListaR03VO;
              if Assigned(ListaR03) then
              begin
                for J := 0 to ListaR03.Count - 1 do
                begin

                  with RegistroR03.New do
                  begin

                    ValorHashRegistro := TR03VO(ListaR03.Items[J]).HashRegistro;
                    TR03VO(ListaR03.Items[J]).Id := 0;
                    TR03VO(ListaR03.Items[J]).HashRegistro := '0';
                    if MD5Print(MD5String(TR03VO(ListaR03.Items[J]).ToJSONString)) <> ValorHashRegistro then
                      RegistroValido := False;

                    TOT_PARCIAL := TR03VO(ListaR03.Items[J]).TotalizadorParcial;
                    VL_ACUM := TR03VO(ListaR03.Items[J]).ValorAcumulado;
                  end; // with RegistroR03.New do
                end; // for j := 0 to ListaR03.Count - 1 do
              end; // if Assigned(ListaR03) then
            end; // with FDataModule.ACBrPAF.PAF_R.RegistroR02.New do
          end; // for i := 0 to ListaR02.Count - 1 do
        end; // if Assigned(ListaR02) then

        // Registro R04 - Cupom Fiscal, Nota Fiscal de Venda a Consumidor ou Bilhete de Passagem - ECF_VENDA_CABECALHO
        // Registro R05 - Detalhe do Cupom Fiscal, Nota Fiscal de Venda a Consumidor ou Bilhete de Passagem - ECF_VENDA_DETALHE
        // Registro R07 - Detalhe do Cupom Fiscal e do Documento N�o Fiscal - Meio de Pagamento
        ListaR04 := Nil;
        Filtro := 'SERIE_ECF = ' + QuotedStr(TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Serie) + ' AND (DATA_VENDA between ' + QuotedStr(DataInicio) + ' and ' + QuotedStr(DataFim) + ')';
        ListaR04 := TVendaController.ConsultaLista(Filtro);
        if Assigned(ListaR04) then
        begin
          for I := 0 to ListaR04.Count - 1 do
          begin

            with RegistroR04.New do
            begin

              ValorHashRegistro := TEcfVendaCabecalhoVO(ListaR04.Items[I]).HashRegistro;
              TEcfVendaCabecalhoVO(ListaR04.Items[I]).HashRegistro := '0';
              if MD5Print(MD5String(TEcfVendaCabecalhoVO(ListaR04.Items[I]).ToJSONString)) <> ValorHashRegistro then
                RegistroValido := False;

              NUM_USU := TEcfVendaCabecalhoVO(ListaR04.Items[I]).IdEcfFuncionario;
              NUM_CONT := TEcfVendaCabecalhoVO(ListaR04.Items[I]).CCF;
              COO := TEcfVendaCabecalhoVO(ListaR04.Items[I]).COO;
              DT_INI := TEcfVendaCabecalhoVO(ListaR04.Items[I]).DataVenda;
              SUB_DOCTO := TEcfVendaCabecalhoVO(ListaR04.Items[I]).ValorVenda;
              SUB_DESCTO := TEcfVendaCabecalhoVO(ListaR04.Items[I]).Desconto;
              TP_DESCTO := 'V';
              SUB_ACRES := TEcfVendaCabecalhoVO(ListaR04.Items[I]).Acrescimo;
              TP_ACRES := 'V';
              VL_TOT := TEcfVendaCabecalhoVO(ListaR04.Items[I]).ValorFinal;
              CANC := TEcfVendaCabecalhoVO(ListaR04.Items[I]).CupomCancelado;
              VL_CA := 0;
              ORDEM_DA := 'D';
              NOME_CLI := TEcfVendaCabecalhoVO(ListaR04.Items[I]).NomeCliente;
              CNPJ_CPF := TEcfVendaCabecalhoVO(ListaR04.Items[I]).CpfCnpjCliente;

              // Registro R05 - FILHO
              ListaR05 := TEcfVendaCabecalhoVO(ListaR04.Items[I]).ListaEcfVendaDetalheVO;
              if Assigned(ListaR05) then
              begin
                for J := 0 to ListaR05.Count - 1 do
                begin
                  with RegistroR05.New do
                  begin

                    ValorHashRegistro := TEcfVendaDetalheVO(ListaR05.Items[J]).HashRegistro;
                    TEcfVendaDetalheVO(ListaR05.Items[J]).Id := 0;
                    TEcfVendaDetalheVO(ListaR05.Items[J]).HashRegistro := '0';
                    if MD5Print(MD5String(TEcfVendaDetalheVO(ListaR05.Items[J]).ToJSONString)) <> ValorHashRegistro then
                      RegistroValido := False;

                    NUM_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).Item;
                    COD_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).GTIN;
                    DESC_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).EcfProdutoVO.DescricaoPDV;
                    QTDE_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).Quantidade;
                    UN_MED := TEcfVendaDetalheVO(ListaR05.Items[J]).EcfProdutoVO.UnidadeEcfProdutoVO.Sigla;
                    VL_UNIT := TEcfVendaDetalheVO(ListaR05.Items[J]).ValorUnitario;
                    DESCTO_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).Desconto;
                    ACRES_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).Acrescimo;
                    VL_TOT_ITEM := TEcfVendaDetalheVO(ListaR05.Items[J]).TotalItem;
                    COD_TOT_PARC := TEcfVendaDetalheVO(ListaR05.Items[J]).TotalizadorParcial;
                    IND_CANC := TEcfVendaDetalheVO(ListaR05.Items[J]).Cancelado;

                    if TEcfVendaDetalheVO(ListaR05.Items[J]).Cancelado = 'S' then
                    begin
                      QTDE_CANC := TEcfVendaDetalheVO(ListaR05.Items[J]).Quantidade;
                      VL_CANC := TEcfVendaDetalheVO(ListaR05.Items[J]).TotalItem;
                    end
                    else
                    begin
                      QTDE_CANC := 0;
                      VL_CANC := 0;
                    end;

                    VL_CANC_ACRES := 0;
                    IAT := TEcfVendaDetalheVO(ListaR05.Items[J]).EcfProdutoVO.IAT;
                    IPPT := TEcfVendaDetalheVO(ListaR05.Items[J]).EcfProdutoVO.IPPT;
                    QTDE_DECIMAL := Sessao.Configuracao.DecimaisQuantidade;
                    VL_DECIMAL := Sessao.Configuracao.DecimaisValor;
                  end; // with RegistroR05.New do
                end; // for j := 0 to ListaR05.Count - 1 do
              end; // if Assigned(ListaR05) then

              // Registro R07 - FILHO DO R04 - MEIOS DE PAGAMENTO
              ListaR07IdR04 := TEcfVendaCabecalhoVO(ListaR04.Items[I]).ListaEcfTotalTipoPagamentoVO;
              if Assigned(ListaR07IdR04) then
              begin
                for J := 0 to ListaR07IdR04.Count - 1 do
                begin

                  with RegistroR07.New do
                  begin
                    ValorHashRegistro := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).HashRegistro;
                    TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).Id := 0;
                    TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).HashRegistro := '0';
                    if MD5Print(MD5String(TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).ToJSONString)) <> ValorHashRegistro then
                      RegistroValido := False;

                    COO := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).COO;
                    CCF := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).CCF;
                    Gnf := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).Gnf;
                    MP := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).EcfTipoPagamentoVO.Descricao;
                    VL_PAGTO := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).Valor;
                    IND_EST := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).Estorno;
                    VL_EST := TEcfTotalTipoPagamentoVO(ListaR07IdR04.Items[J]).Valor;
                  end; // with RegistroR07.New do
                end; // for j := 0 to ListaR07.Count - 1 do
              end; // if Assigned(ListaR07) then
            end; // with FDataModule.ACBrPAF.PAF_R.RegistroR04.New do
          end; // for i := 0 to ListaR04.Count - 1 do
        end; // if Assigned(ListaR04) then

        // Registro R06 - Demais documentos emitidos pelo ECF
        // Registro R07 - Detalhe do Cupom Fiscal e do Documento N�o Fiscal - Meio de Pagamento
        ListaR06 := Nil;
        Filtro := 'SERIE_ECF = ' + QuotedStr(TEcfImpressoraVO(Sessao.ListaImpressora.Items[H]).Serie) + ' AND (DATA_EMISSAO between ' + QuotedStr(DataInicio) + ' and ' + QuotedStr(DataFim) + ')';
        ListaR06 := TR06Controller.ConsultaLista(Filtro);
        if Assigned(ListaR06) then
        begin
          for I := 0 to ListaR06.Count - 1 do
          begin

            with RegistroR06.New do
            begin

              ValorHashRegistro := TR06VO(ListaR06.Items[I]).HashRegistro;
              TR06VO(ListaR06.Items[I]).Id := 0;
              TR06VO(ListaR06.Items[I]).HashRegistro := '0';
              if MD5Print(MD5String(TR06VO(ListaR06.Items[I]).ToJSONString)) <> ValorHashRegistro then
                RegistroValido := False;

              NUM_USU := TR06VO(ListaR06.Items[I]).IdOperador;
              COO := TR06VO(ListaR06.Items[I]).COO;
              Gnf := TR06VO(ListaR06.Items[I]).Gnf;
              GRG := TR06VO(ListaR06.Items[I]).GRG;
              CDC := TR06VO(ListaR06.Items[I]).CDC;
              DENOM := TR06VO(ListaR06.Items[I]).Denominacao;
              DT_FIN := TR06VO(ListaR06.Items[I]).DataEmissao;
              HR_FIN := StrToDateTime(TR06VO(ListaR06.Items[I]).HoraEmissao);

              // Registro R07 - FILHO DE R06
              ListaR07 := TR06VO(ListaR06.Items[I]).ListaR07VO;
              if Assigned(ListaR07) then
              begin
                for J := 0 to ListaR07.Count - 1 do
                begin
                  with RegistroR07.New do
                  begin
                    ValorHashRegistro := TR07VO(ListaR07.Items[J]).HashRegistro;
                    TR07VO(ListaR07.Items[J]).Id := 0;
                    TR07VO(ListaR07.Items[J]).HashRegistro := '0';
                    if MD5Print(MD5String(TR07VO(ListaR07.Items[J]).ToJSONString)) <> ValorHashRegistro then
                      RegistroValido := False;

                    CCF := TR07VO(ListaR07.Items[J]).CCF;
                    MP := TR07VO(ListaR07.Items[J]).MeioPagamento;
                    VL_PAGTO := TR07VO(ListaR07.Items[J]).ValorPagamento;
                    IND_EST := TR07VO(ListaR07.Items[J]).Estorno;
                    VL_EST := TR07VO(ListaR07.Items[J]).ValorEstorno;
                  end; // with RegistroR07.New do
                end; // for j := 0 to ListaR07.Count - 1 do
              end; // if Assigned(ListaR07) then
            end; // with FDataModule.ACBrPAF.PAF_R.RegistroR06.New do
          end; // for i := 0 to ListaR06.Count - 1 do
        end; // if Assigned(ListaR06) then

      end;

    end;
  finally
    ListaR02 := Nil;
    ListaR04 := Nil;
    ListaR06 := Nil;
  end;
end;
{$ENDREGION 'Gera��o Arquivo Registros PAF'}

{$REGION 'Relat�rios Gerenciais'}
class procedure TPAFUtil.IdentificacaoPafEcf;
var
  ArquivoIni: TIniFile;
  MD5Arquivo: String;
  I, QuantidadeECF: Integer;
begin
  try
    FDataModule.ACBrECF.AbreRelatorioGerencial(Sessao.Configuracao.EcfRelatorioGerencialVO.X);

    FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));
    FDataModule.ACBrECF.LinhaRelatorioGerencial('************IDENTIFICACAO DO PAF-ECF************');
    FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NUMERO DO LAUDO...: ' + Sessao.R01.NumeroLaudoPaf);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('*****IDENTIFICACAO DA EMPRESA DESENVOLVEDORA****');
    FDataModule.ACBrECF.LinhaRelatorioGerencial('C.N.P.J. .........: ' + Sessao.R01.CnpjSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('RAZAO SOCIAL......: ' + Sessao.R01.RazaoSocialSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('ENDERECO..........: ' + Sessao.R01.EnderecoSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NUMERO............: ' + Sessao.R01.NumeroSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('COMPLEMENTO.......: ' + Sessao.R01.ComplementoSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('BAIRRO............: ' + Sessao.R01.BairroSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('CIDADE............: ' + Sessao.R01.CidadeSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('CEP...............: ' + Sessao.R01.CepSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('UF................: ' + Sessao.R01.UfSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('TELEFONE..........: ' + Sessao.R01.TelefoneSh);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('CONTATO...........: ' + Sessao.R01.ContatoSh);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('************IDENTIFICACAO DO PAF-ECF************');
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NOME COMERCIAL....: ' + Sessao.R01.NomePafEcf);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('VERSAO DO PAF-ECF.: ' + Sessao.R01.VersaoPafEcf);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('**********PRINCIPAL ARQUIVO EXECUTAVEL**********');
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NOME..............: ' + Sessao.R01.PrincipalExecutavel);
    MD5Arquivo := MD5Print(MD5File(ExtractFilePath(Application.ExeName) + Sessao.R01.PrincipalExecutavel));
    FDataModule.ACBrECF.LinhaRelatorioGerencial('MD5.: ' + MD5Arquivo);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('****************DEMAIS ARQUIVOS*****************');
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NOME..............: ' + 'Balcao.exe');
    MD5Arquivo := MD5Print(MD5File(ExtractFilePath(Application.ExeName) + 'Balcao.exe'));
    FDataModule.ACBrECF.LinhaRelatorioGerencial('MD5.: ' + MD5Arquivo);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('**************NOME DO ARQUIVO TEXTO*************');
    FDataModule.ACBrECF.LinhaRelatorioGerencial('NOME..............: ' + 'ArquivoMD5.txt');
    try
      ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
      MD5Arquivo := Codifica('D', ArquivoIni.ReadString('MD5', 'ARQUIVOS', ''));
    finally
      ArquivoIni.Free;
    end;
    FDataModule.ACBrECF.LinhaRelatorioGerencial('MD5.: ' + MD5Arquivo);
    FDataModule.ACBrECF.LinhaRelatorioGerencial('VERSAO ER PAF-ECF.: ' + Sessao.R01.VersaoEr);

    FDataModule.ACBrECF.LinhaRelatorioGerencial('**********RELACAO DOS ECF AUTORIZADOS***********');
    for I := 0 to Sessao.ECFsAutorizados.Count - 1 do
    begin
      FDataModule.ACBrECF.LinhaRelatorioGerencial(Sessao.ECFsAutorizados[I]);
    end;

    FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));
    FDataModule.ACBrECF.FechaRelatorio;

    GravarR06('RG');
  finally
  end;
end;

class procedure TPAFUtil.ParametrodeConfiguracao;
var
  ArquivoIni: TIniFile;
begin
  try
    try
      ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');

      FDataModule.ACBrECF.AbreRelatorioGerencial(Sessao.Configuracao.EcfRelatorioGerencialVO.X);
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('***********PARAMETROS DE CONFIGURACAO***********');
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('<n>CONFIGURA��O:</n>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>Funcionalidades:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TIPO DE FUNCIONAMENTO: ......... ' + (Codifica('D', Trim(ArquivoIni.ReadString('FUNCIONALIDADES', 'FUN1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TIPO DE DESENVOLVIMENTO: ....... ' + (Codifica('D', Trim(ArquivoIni.ReadString('FUNCIONALIDADES', 'FUN2', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('INTEGRACAO DO PAF-ECF: ......... ' + (Codifica('D', Trim(ArquivoIni.ReadString('FUNCIONALIDADES', 'FUN3', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>Par�metros Para N�o Concomit�ncia:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('PR�-VENDA: ................................. ' + (Codifica('D', Trim(ArquivoIni.ReadString('PARAMETROSPARANAOCONCOMITANCIA', 'PAR1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('DAV POR ECF: ............................... ' + (Codifica('D', Trim(ArquivoIni.ReadString('PARAMETROSPARANAOCONCOMITANCIA', 'PAR2', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('DAV IMPRESSORA N�O FISCAL: ................. ' + (Codifica('D', Trim(ArquivoIni.ReadString('PARAMETROSPARANAOCONCOMITANCIA', 'PAR3', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('DAV-OS: .................................... ' + (Codifica('D', Trim(ArquivoIni.ReadString('PARAMETROSPARANAOCONCOMITANCIA', 'PAR4', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>Aplica��es Especiais:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TAB. �NDICE T�CNICO DE PRODU��O: ........... ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('POSTO REVENDEDOR DE COMBUST�VEIS: .......... ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL2', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('Bar, Restaurante e Similar - ECF-Restaurante:' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL3', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('Bar, Restaurante e Similar - ECF-Comum: .... ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL4', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('FARM�CIA DE MANIPULA��O: ................... ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL5', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('OFICINA DE CONSERTO: ....................... ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL6', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TRANSPORTE DE PASSAGEIROS: ................. ' + (Codifica('D', Trim(ArquivoIni.ReadString('APLICATIVOSESPECIAIS', 'APL7', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>Crit�rios por Unidade Federada:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('<n>REQUISITO XVIII - Tela Consulta de Pre�o:</n>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TOTALIZA��O DOS VALORES DA LISTA: .......... ' + (Codifica('D', Trim(ArquivoIni.ReadString('CRITERIOSPORUNIDADEFEDERADA', 'CRI1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TRANSFORMA��O DAS INFORM��ES EM PR�-VENDA: . ' + (Codifica('D', Trim(ArquivoIni.ReadString('CRITERIOSPORUNIDADEFEDERADA', 'CRI2', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial('TRANSFORMA��O DAS INFORM��ES EM DAV: ....... ' + (Codifica('D', Trim(ArquivoIni.ReadString('CRITERIOSPORUNIDADEFEDERADA', 'CRI3', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>REQUISITO XXII - PAF-ECF Integrado ao ECF:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('N�O COINCID�NCIA GT(ECF) x ARQUIVO CRIPTOGRAFADO');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('RECOMPOE VALOR DO GT ARQUIVO CRIPTOGRAFADO:  ' + (Codifica('D', Trim(ArquivoIni.ReadString('XXIIREQUISITO', 'XXII1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.LinhaRelatorioGerencial('<s><n>REQUISITO XXXVI - A - PAF-ECF Combust�vel:</n></s>');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('Impedir Registro de Venda com Valor Zero ou');
      FDataModule.ACBrECF.LinhaRelatorioGerencial('Negativo: .................................. ' + (Codifica('D', Trim(ArquivoIni.ReadString('XXXVIREQUISITO', 'XXXVI1', '')))));
      FDataModule.ACBrECF.LinhaRelatorioGerencial(StringOfChar('=', 48));

      FDataModule.ACBrECF.FechaRelatorio;

      GravarR06('RG');
    except
      Application.MessageBox('N�o foi poss�vel carregar dados do ArquivoAuxiliar.ini.', 'Informa��o do Sistema', MB_OK + MB_ICONERROR);
    end;
  finally
    ArquivoIni.Free;
  end;
end;
{$ENDREGION 'Relat�rios Gerenciais'}

{$REGION 'Grava��o de Dados'}
class procedure TPAFUtil.GravarR02R03;
var
  R02: TR02VO;
  R03: TR03VO;
  I: Integer;
  Indice, Aliquota: String;
begin
  try
    // Dados para o registro R02
    R02 := TR02VO.Create;
    R02.IdEcfCaixa := Sessao.Movimento.IdEcfCaixa;
    R02.IdOperador := Sessao.Movimento.IdEcfOperador;
    R02.IdImpressora := Sessao.Movimento.IdEcfImpressora;
    R02.SerieEcf := Sessao.Configuracao.EcfImpressoraVO.Serie;

    FDataModule.ACBrECF.DadosReducaoZ;
    with FDataModule.ACBrECF.DadosReducaoZClass do
    begin
      R02.CRZ := CRZ + 1;
      R02.COO := StrToInt(FDataModule.ACBrECF.NumCOO) + 1;
      R02.CRO := CRO;
      R02.DataMovimento := DataDoMovimento;
      R02.DataEmissao := DataDaImpressora;
      R02.HoraEmissao := FormatDateTime('hh:mm:ss', DataDaImpressora);
      R02.VendaBruta := ValorVendaBruta;
      R02.GrandeTotal := ValorGrandeTotal;
    end;

    // Dados para o registro R03
    with FDataModule.ACBrECF.DadosReducaoZClass do
    begin
      // Dados ICMS
      for I := 0 to ICMS.Count - 1 do
      begin
        R03 := TR03VO.Create;
        R03.CRZ := CRZ + 1;
        // Completa com zeros a esquerda
        Indice := StringOfChar('0', 2 - length(ICMS[I].Indice)) + ICMS[I].Indice;
        // Tira as virgulas
        Aliquota := StringReplace(FloatToStr(ICMS[I].Aliquota * 100), ',', '', [rfReplaceAll]);
        // Completa com zeros a esquerda e a direita
        Aliquota := StringOfChar('0', 4 - length(Aliquota)) + Aliquota;
        R03.TotalizadorParcial := Indice + 'T' + Aliquota;
        R03.ValorAcumulado := ICMS[I].Total;
        R02.ListaR03VO.Add(R03);
      end;
      // Dados ISSQN
      for I := 0 to ISSQN.Count - 1 do
      begin
        R03 := TR03VO.Create;
        // Completa com zeros a esquerda
        Indice := StringOfChar('0', 2 - length(ISSQN[I].Indice)) + ISSQN[I].Indice;
        // Tira as virgulas
        Aliquota := StringReplace(FloatToStr(ISSQN[I].Aliquota * 100), ',', '', [rfReplaceAll]);
        // Completa com zeros a esquerda
        Aliquota := StringOfChar('0', 4 - length(Aliquota)) + Aliquota;
        R03.TotalizadorParcial := Indice + 'S' + Aliquota;
        R03.ValorAcumulado := ISSQN[I].Total;
        R02.ListaR03VO.Add(R03);
      end;
      // Substitui��o Tribut�ria - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'F1';
      R03.ValorAcumulado := SubstituicaoTributariaICMS;
      R02.ListaR03VO.Add(R03);

      // Isento - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'I1';
      R03.ValorAcumulado := IsentoICMS;
      R02.ListaR03VO.Add(R03);

      // N�o-incid�ncia - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'N1';
      R03.ValorAcumulado := NaoTributadoICMS;
      R02.ListaR03VO.Add(R03);

      // Substitui��o Tribut�ria - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'FS1';
      R03.ValorAcumulado := SubstituicaoTributariaISSQN;
      R02.ListaR03VO.Add(R03);

      // Isento - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'IS1';
      R03.ValorAcumulado := IsentoISSQN;
      R02.ListaR03VO.Add(R03);

      // N�o-incid�ncia - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'NS1';
      R03.ValorAcumulado := NaoTributadoISSQN;
      R02.ListaR03VO.Add(R03);

      // Opera��es N�o Fiscais
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'OPNF';
      R03.ValorAcumulado := TotalOperacaoNaoFiscal;
      R02.ListaR03VO.Add(R03);

      // Desconto - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'DT';
      R03.ValorAcumulado := DescontoICMS;
      R02.ListaR03VO.Add(R03);

      // Desconto - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'DS';
      R03.ValorAcumulado := DescontoISSQN;
      R02.ListaR03VO.Add(R03);

      // Acr�scimo - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'AT';
      R03.ValorAcumulado := AcrescimoICMS;
      R02.ListaR03VO.Add(R03);

      // Acr�scimo - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'AS';
      R03.ValorAcumulado := AcrescimoISSQN;
      R02.ListaR03VO.Add(R03);

      // Cancelamento - ICMS
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'Can-T';
      R03.ValorAcumulado := CancelamentoICMS;
      R02.ListaR03VO.Add(R03);

      // Cancelamento - ISSQN
      R03 := TR03VO.Create;
      R03.TotalizadorParcial := 'Can-S';
      R03.ValorAcumulado := CancelamentoISSQN;
      R02.ListaR03VO.Add(R03);
    end;

    // InsereObjeto - Objeto inserido retorna para a vari�vel ObjetoConsultado do Controller
    TR02Controller.Insere(R02);

    if FCargaPDV = nil then
      Application.CreateForm(TFCargaPDV, FCargaPDV);
    FCargaPDV.Procedimento := 'EXPORTA_R02';
    FCargaPDV.Timer.Enabled := True;

    Gravar60M60A;

  finally
    if Assigned(R02) then
      FreeAndNil(R02);
  end;
end;

class procedure TPAFUtil.Gravar60M60A;
var
  I: Integer;
  Sintegra60M: TSintegra60MVO;
  Sintegra60A: TSintegra60AVO;
begin
  try

    Sintegra60M := TSintegra60MVO.Create;
    Sintegra60M.ModeloDocumentoFiscal := Sessao.Configuracao.EcfImpressoraVO.ModeloDocumentoFiscal;

    with FDataModule.ACBrECF.DadosReducaoZClass do
    begin
      Sintegra60M.DataEmissao := DataDoMovimento;
      Sintegra60M.NumeroSerieEcf := NumeroDeSerie;
      Sintegra60M.NumeroEquipamento := StrToInt(NumeroDoECF);
      Sintegra60M.COOInicial := StrToInt(NumeroCOOInicial);
      Sintegra60M.COOFinal := COO + 1;
      Sintegra60M.CRZ := CRZ + 1;
      Sintegra60M.CRO := CRO;
      Sintegra60M.ValorVendaBruta := ValorVendaBruta;
      Sintegra60M.ValorGrandeTotal := ValorGrandeTotal;
    end;

    // Dados para o registro Sintegra 60A
    with FDataModule.ACBrECF.DadosReducaoZClass do
    begin
      // Dados ICMS
      for I := 0 to ICMS.Count - 1 do
      begin
        Sintegra60A := TSintegra60AVO.Create;
        Sintegra60A.IdSintegra60m := Sintegra60M.Id;
        Sintegra60A.SituacaoTributaria := StringReplace(FloatToStr(ICMS[I].Aliquota), ',', '', [rfReplaceAll]);
        Sintegra60A.Valor := ICMS[I].Total;
        Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);
      end;

      // Dados ISSQN
      for I := 0 to ISSQN.Count - 1 do
      begin
        Sintegra60A := TSintegra60AVO.Create;
        Sintegra60A.IdSintegra60m := Sintegra60M.Id;
        Sintegra60A.SituacaoTributaria := StringReplace(FloatToStr(ISSQN[I].Aliquota), ',', '', [rfReplaceAll]);
        Sintegra60A.Valor := ISSQN[I].Total;
        Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);
      end;

      // Substitui��o Tribut�ria - ICMS
      Sintegra60A := TSintegra60AVO.Create;
      Sintegra60A.IdSintegra60m := Sintegra60M.Id;
      Sintegra60A.SituacaoTributaria := 'F';
      Sintegra60A.Valor := SubstituicaoTributariaICMS;
      Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);

      // Isento - ICMS
      Sintegra60A := TSintegra60AVO.Create;
      Sintegra60A.IdSintegra60m := Sintegra60M.Id;
      Sintegra60A.SituacaoTributaria := 'I';
      Sintegra60A.Valor := IsentoICMS;
      Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);

      // N�o-incid�ncia - ICMS
      Sintegra60A := TSintegra60AVO.Create;
      Sintegra60A.IdSintegra60m := Sintegra60M.Id;
      Sintegra60A.SituacaoTributaria := 'N';
      Sintegra60A.Valor := NaoTributadoICMS;
      Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);

      // Desconto - ICMS
      Sintegra60A := TSintegra60AVO.Create;
      Sintegra60A.IdSintegra60m := Sintegra60M.Id;
      Sintegra60A.SituacaoTributaria := 'DESC';
      Sintegra60A.Valor := DescontoICMS;
      Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);

      // Cancelamento - ICMS
      Sintegra60A := TSintegra60AVO.Create;
      Sintegra60A.IdSintegra60m := Sintegra60M.Id;
      Sintegra60A.SituacaoTributaria := 'CANC';
      Sintegra60A.Valor := CancelamentoICMS;
      Sintegra60M.ListaSintegra60aVO.Add(Sintegra60A);
    end;

    // InsereObjeto - Objeto inserido retorna para a vari�vel ObjetoConsultado do Controller
    TSintegra60MController.Insere(Sintegra60M);

    if FCargaPDV = nil then
      Application.CreateForm(TFCargaPDV, FCargaPDV);
    FCargaPDV.Procedimento := 'EXPORTA_SINTEGRA60M';
    FCargaPDV.Timer.Enabled := True;

  finally
    if Assigned(Sintegra60M) then
      FreeAndNil(Sintegra60M);
  end;
end;

class procedure TPAFUtil.GravarR06(Simbolo: String);
var
  R06: TR06VO;
begin
  try
    R06 := TR06VO.Create;
    R06.IdEcfCaixa := Sessao.Movimento.IdEcfCaixa;
    R06.IdOperador := Sessao.Movimento.IdEcfOperador;
    R06.IdImpressora := Sessao.Movimento.IdEcfImpressora;
    R06.SerieEcf := Sessao.Configuracao.EcfImpressoraVO.Serie;
    R06.COO := StrToInt(FDataModule.ACBrECF.NumCOO);
    R06.Gnf := StrToInt(FDataModule.ACBrECF.NumGNF);
    R06.GRG := StrToInt(FDataModule.ACBrECF.NumGRG);

    if FDataModule.ACBrECF.MFD then
      R06.CDC := StrToInt(FDataModule.ACBrECF.NumCDC)
    else
      R06.CDC := 0;

    R06.Denominacao := Simbolo;
    { Rela��o do S�mbolos Poss�veis
      Documento                        S�mbolo
      ========================================
      Confer�ncia de Mesa                 - CM
      Registro de Venda                   - RV
      Comprovante de Cr�dito ou D�bito    - CC
      Comprovante N�o-Fiscal              - CN
      Comprovante N�o-Fiscal Cancelamento - NC
      Relat�rio Gerencial                 - RG }
    R06.DataEmissao := EncodeDate(YearOf(FDataModule.ACBrECF.DataHora), MonthOf(FDataModule.ACBrECF.DataHora), DayOf(FDataModule.ACBrECF.DataHora));
    R06.HoraEmissao := FormatDateTime('hh:nn:ss', FDataModule.ACBrECF.DataHora);

    // InsereObjeto - Objeto inserido retorna para a vari�vel ObjetoConsultado do Controller
    TR06Controller.Insere(R06);
    TLogssController.AtualizarQuantidades;

    if FCargaPDV = nil then
      Application.CreateForm(TFCargaPDV, FCargaPDV);
    FCargaPDV.Filtro := 'ID = ' + IntToStr(R06.Id);
    FCargaPDV.Procedimento := 'EXPORTA_R06';
    FCargaPDV.Timer.Enabled := True;
  finally
    FreeAndNil(R06);
  end;
end;
{$ENDREGION 'Grava��o de Dados'}

{$REGION 'Arquivo Auxiliar'}
class function TPAFUtil.ECFAutorizado: Boolean;
var
  MD5Serie, Serie: String;
  ArquivoIni: TIniFile;
  I, Quantidade: Integer;
  Filtro: String;
  R02: TR02VO;
begin
  if not FileExists(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini') then
    Result := False
  else
  begin
    try
      Result := False;
      ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
      Quantidade := Sessao.ECFsAutorizados.Count;
      if ArquivoIni.ValueExists('SERIES', 'SERIE1') then
      begin
        MD5Serie := FDataModule.ACBrECF.NumSerie;
        if Quantidade > 0 then
        begin
          for I := 1 to Quantidade do
          begin
            Serie := 'SERIE' + IntToStr(I);
            if Codifica('D', ArquivoIni.ReadString('SERIES', PChar(Serie), '')) = MD5Serie then
            begin
              Result := True;
              Break;
            end;
          end;
        end;
      end
      else
      begin
        try
          Filtro := ' SERIE_ECF = ' + QuotedStr(Sessao.Configuracao.EcfImpressoraVO.Serie) + ' AND DATA_MOVIMENTO = ' + QuotedStr(DataParaTexto(FDataModule.ACBrECF.DataHoraUltimaReducaoZ));
          R02 := TR02Controller.ConsultaObjeto(Filtro);

          if Assigned(R02) then
          begin
            if (R02.CRZ = StrToInt(FDataModule.ACBrECF.NumCRZ)) and (R02.CRO = StrToInt(FDataModule.ACBrECF.NumCRO)) and (R02.GrandeTotal = FDataModule.ACBrECF.GrandeTotal) then
            begin
              ArquivoIni.WriteString('SERIES', 'SERIE1', Codifica('C', FDataModule.ACBrECF.NumSerie));
              Result := True;
            end
            else
              Result := False;
          end
          else
            Result := False;

        finally
          FreeAndNil(R02);
        end;
      end; // if ini.ValueExists('SERIES','SERIE1') then
    finally
      ArquivoIni.Free;
    end;
  end; // if not FileExists(ExtractFilePath(Application.ExeName)+'ArquivoAuxiliar.ini') then
end;

class function TPAFUtil.ConfereGT: Boolean;
var
  ArquivoIni: TIniFile;
  sGT: String;
  Filtro: String;
  R02: TR02VO;
begin
  if not FileExists(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini') then
    Result := False
  else
  begin
    try
      ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
      sGT := Codifica('D', ArquivoIni.ReadString('ECF', 'GT', ''));
      if sGT = FloatToStr(FDataModule.ACBrECF.GrandeTotal) then
        Result := True
      else
      begin
        Filtro := ' SERIE_ECF = ' + QuotedStr(Sessao.Configuracao.EcfImpressoraVO.Serie) + ' AND DATA_MOVIMENTO = ' + QuotedStr(DataParaTexto(FDataModule.ACBrECF.DataHoraUltimaReducaoZ));
        R02 := TR02Controller.ConsultaObjeto(Filtro);

        if ArquivoIni.ValueExists('ECF', 'GT') then
        begin
          Result := False;
          sGT := Codifica('D', ArquivoIni.ReadString('XXIIREQUISITO', 'XXII2', ''));
          if (sGT = 'SIM') then
          begin

            if Assigned(R02) then
            begin
              if (StrToInt(FDataModule.ACBrECF.NumCRO) > R02.CRO) then
              begin
                ArquivoIni.WriteString('ECF', 'GT', Codifica('C', FloatToStr(FDataModule.ACBrECF.GrandeTotal)));
                Result := True;
              end
              else
                Result := False;
            end
            else
              Result := False;

          end; // if (sGT = 'SIM') then

        end
        else
        begin

          if Assigned(R02) then
          begin
            try
              if (R02.CRZ = StrToInt(FDataModule.ACBrECF.NumCRZ)) and (R02.CRO = StrToInt(FDataModule.ACBrECF.NumCRO)) and (R02.GrandeTotal = FDataModule.ACBrECF.GrandeTotal) then
              begin
                ArquivoIni.WriteString('ECF', 'GT', Codifica('C', FloatToStr(FDataModule.ACBrECF.GrandeTotal)));
                Result := True;
              end
              else
                Result := False;
            finally
              R02.Free;
            end;
          end
          else
            Result := False;

        end; // if ini.ValueExists('ECF','GT') then
      end; // if sGT = FloatToStr(FDataModule.ACBrECF.GrandeTotal) then
    finally
      ArquivoIni.Free;
    end;
  end; // if not FileExists(ExtractFilePath(Application.ExeName)+'ArquivoAuxiliar.ini') then
end;

class procedure TPAFUtil.AtualizaGT;
var
  ArquivoIni: TIniFile;
begin
  try
    ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
    ArquivoIni.WriteString('ECF', 'GT', Codifica('C', FloatToStr(FDataModule.ACBrECF.GrandeTotal)));
  finally
    ArquivoIni.Free;
  end;
end;

class procedure TPAFUtil.GravarIdUltimaVenda;
var
  ArquivoIni: TIniFile;
begin
  try
    ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
    ArquivoIni.WriteInteger('VENDA', 'ULTIMAVENDA', Sessao.VendaAtual.Id);
    AtualizarEstoque(False);
  finally
    ArquivoIni.Free;
  end;
end;

class function TPAFUtil.RecuperarIdUltimaVenda: String;
var
  ArquivoIni: TIniFile;
begin
  try
    ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
    Result := ArquivoIni.ReadString('VENDA', 'ULTIMAVENDA', '0')
  finally
    ArquivoIni.Free;
  end;
end;

class function TPAFUtil.AtualizarEstoque(pForcarAtualizacao: Boolean): Boolean;
var
  ArquivoIni: TIniFile;
  DataECF: TDateTime;
  DataEstoque: String;
  RegistroE3: TEcfE3VO;
  ListaProduto: TListaEcfProdutoVO;
  Camadas, I: Integer;
begin
  (*
  Usar o Brook

  try
    // Guarda Camadas. Se ocorrer algum problema, no Finally tem que setar o mesmo valor
    Camadas := Sessao.Camadas;

    if TController.ServidorAtivo then
    begin
      try
        ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
        DataEstoque := ArquivoIni.ReadString('VENDA', 'DATAESTOQUE', '');
        DataECF := EncodeDate(YearOf(FDataModule.ACBrECF.DataHora), MonthOf(FDataModule.ACBrECF.DataHora), DayOf(FDataModule.ACBrECF.DataHora));

        if (DataEstoque = '') or (StrToDate(DataEstoque) < DataECF) or (pForcarAtualizacao) then
        begin
          RegistroE3 := TEcfE3VO.Create;
          RegistroE3.SerieEcf := Sessao.Configuracao.EcfImpressoraVO.Serie;
          RegistroE3.MfAdicional := FDataModule.ACBrECF.MfAdicional;
          RegistroE3.TipoEcf := Sessao.Configuracao.EcfImpressoraVO.Tipo;
          RegistroE3.MarcaEcf := Sessao.Configuracao.EcfImpressoraVO.Marca;
          RegistroE3.ModeloEcf := Sessao.Configuracao.EcfImpressoraVO.Modelo;
          RegistroE3.DataEstoque := DataECF;
          RegistroE3.HoraEstoque := FormatDateTime('hh:nn:ss', FDataModule.ACBrECF.DataHora);

          Sessao.Camadas := 3;
          TProdutoController.AtualizaEstoquePAF(RegistroE3);
          FreeAndNil(RegistroE3);
          RegistroE3 := TEcfE3VO(TController.ObjetoConsultado.Clone);
          FreeAndNil(TController.ObjetoConsultado);

          // Baixa a lista de produtos para atualizar o estoque - Consulta realizada no servidor
          ListaProduto := TProdutoController.ConsultaLista('ID>0');

          // Verifica se o registro j� foi armazenado no banco local, se n�o foi armazena
          if Assigned(RegistroE3) then
          begin
            Sessao.Camadas := 2;
            TEcfE3Controller.EcfE3('ID=' + IntToStr(RegistroE3.Id);
            if not Assigned(TController.ObjetoConsultado) then
            begin
              RegistroE3.HashRegistro := '0';
              RegistroE3.HashRegistro := MD5Print(MD5String(RegistroE3.ToJSONString));
              TEcfE3Controller.Insere(RegistroE3);
            end;
            FreeAndNil(TController.ObjetoConsultado);
          end;
          for I := 0 to ListaProduto.Count - 1 do
          begin
            TProdutoController.Altera(TEcfProdutoVO(ListaProduto[I]));
          end;

          ArquivoIni.WriteString('VENDA', 'DATAESTOQUE', DateToStr(DataECF));
          Result := True;
        end;
      except
        on E: Exception do
        begin
          Result := False;
          Application.MessageBox(PChar('Ocorreu um erro durante a gera��o do arquivo. Informe a mensagem ao Administrador do sistema.' + #13 + #13 + E.Message), 'Erro do sistema', MB_OK + MB_ICONERROR);
        end;
      end;
    end
    else
    begin
      Result := False;
    end;
  finally
    Sessao.Camadas := Camadas;
    ArquivoIni.Free;
    FreeAndNil(RegistroE3);
    FreeAndNil(ListaProduto);
  end;
  *)
end;
{$ENDREGION 'Arquivo Auxiliar'}

{$REGION 'Outros Procedimentos'}
class function TPAFUtil.GeraMD5: String;
var
  NomeArquivo, Mensagem, MD5ArquivoMD5: String;
  ArquivoIni: TIniFile;
begin
  // registro N2
  try

    FDataModule.ACBrPAF.PAF_N.RegistroN2.LAUDO := Sessao.R01.NumeroLaudoPaf;
    FDataModule.ACBrPAF.PAF_N.RegistroN2.NOME := Sessao.R01.NomePafEcf;
    FDataModule.ACBrPAF.PAF_N.RegistroN2.Versao := Sessao.R01.VersaoPafEcf;

    FDataModule.ACBrPAF.PAF_N.RegistroN3.Clear;

    NomeArquivo := ExtractFilePath(Application.ExeName) + 'PafEcf.exe';
    with FDataModule.ACBrPAF.PAF_N.RegistroN3.New do
    begin
      NOME_ARQUIVO := Sessao.R01.PrincipalExecutavel;
      MD5 := MD5Print(MD5File(NomeArquivo));
    end;

    NomeArquivo := ExtractFilePath(Application.ExeName) + 'Balcao.exe';
    with FDataModule.ACBrPAF.PAF_N.RegistroN3.New do
    begin
      NOME_ARQUIVO := 'Balcao.exe';
      MD5 := MD5Print(MD5File(NomeArquivo));
    end;

    FDataModule.ACBrPAF.SaveFileTXT_N('ArquivoMD5.txt');

    MD5ArquivoMD5 := MD5Print(MD5File(ExtractFilePath(Application.ExeName) + 'ArquivoMD5.txt'));

    try
      ArquivoIni := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'ArquivoAuxiliar.ini');
      ArquivoIni.WriteString('MD5', 'ARQUIVOS', Codifica('C', MD5ArquivoMD5));
    finally
      ArquivoIni.Free;
    end;

    Mensagem := 'Arquivo armazenado em: ' + ExtractFilePath(Application.ExeName) + 'ArquivoMD5.txt';
    Application.MessageBox(PChar(Mensagem), 'Informa��o do Sistema', MB_OK + MB_ICONINFORMATION);
  finally
  end;
  Result := MD5ArquivoMD5;
end;
{$ENDREGION 'Outros Procedimentos'}

end.
