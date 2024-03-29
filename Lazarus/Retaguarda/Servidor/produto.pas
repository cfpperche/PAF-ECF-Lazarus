unit Produto;

{$mode objfpc}{$H+}

interface

uses
  BrookRESTActions, BrookUtils;

type

  { TProdutoOptions }

  TProdutoOptions = class(TBrookOptionsAction)
  end;

  TProdutoRetrieve = class(TBrookRetrieveAction)
  end;

  TProdutoShow = class(TBrookShowAction)
  end;

  TProdutoCreate = class(TBrookCreateAction)
  end;

  TProdutoUpdate = class(TBrookUpdateAction)
  end;

  TProdutoDestroy = class(TBrookDestroyAction)
  end;

implementation

{ TProdutoOptions }

initialization
  TProdutoOptions.Register('produto', '/produto');
  TProdutoRetrieve.Register('produto', '/produto');
  TProdutoShow.Register('produto', '/produto/:id');
  TProdutoCreate.Register('produto', '/produto');
  TProdutoUpdate.Register('produto', '/produto/:id');
  TProdutoDestroy.Register('produto', '/produto/:id');

end.
