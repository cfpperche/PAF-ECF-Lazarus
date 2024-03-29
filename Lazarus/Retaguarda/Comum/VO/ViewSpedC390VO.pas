{*******************************************************************************
Title: T2Ti ERP                                                                 
Description:  VO  relacionado � tabela [VIEW_SPED_C390] 
                                                                                
The MIT License                                                                 
                                                                                
Copyright: Copyright (C) 2014 T2Ti.COM                                          
                                                                                
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
           t2ti.com@gmail.com                                                   
                                                                                
@author Albert Eije (t2ti.com@gmail.com)                    
@version 2.0                                                                    
*******************************************************************************}
unit ViewSpedC390VO;

{$mode objfpc}{$H+}

interface

uses
  VO, Classes, SysUtils, FGL;

type
  TViewSpedC390VO = class(TVO)
  private
    FID: Integer;
    FCST: String;
    FCFOP: Integer;
    FTAXA_ICMS: Extended;
    FDATA_EMISSAO: TDateTime;
    FSOMA_ITEM: Extended;
    FSOMA_BASE_ICMS: Extended;
    FSOMA_ICMS: Extended;
    FSOMA_ICMS_OUTRAS: Extended;

  published 
    property Id: Integer  read FID write FID;
    property Cst: String  read FCST write FCST;
    property Cfop: Integer  read FCFOP write FCFOP;
    property TaxaIcms: Extended  read FTAXA_ICMS write FTAXA_ICMS;
    property DataEmissao: TDateTime  read FDATA_EMISSAO write FDATA_EMISSAO;
    property SomaItem: Extended  read FSOMA_ITEM write FSOMA_ITEM;
    property SomaBaseIcms: Extended  read FSOMA_BASE_ICMS write FSOMA_BASE_ICMS;
    property SomaIcms: Extended  read FSOMA_ICMS write FSOMA_ICMS;
    property SomaIcmsOutras: Extended  read FSOMA_ICMS_OUTRAS write FSOMA_ICMS_OUTRAS;

  end;

  TListaViewSpedC390VO = specialize TFPGObjectList<TViewSpedC390VO>;

implementation


initialization
  Classes.RegisterClass(TViewSpedC390VO);

finalization
  Classes.UnRegisterClass(TViewSpedC390VO);

end.
