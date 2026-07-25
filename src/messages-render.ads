with Messages.AST;
with Messages.Errors;
with Messages.Arguments;

private package Messages.Render is

   --  Regression-only AST renderer: the in-tree compatibility/differential
   --  tests walk the AST directly through this path. It is NOT on the public
   --  render path (Messages.Runtime supersedes it) and is NOT locale-faithful --
   --  it hardcodes Locale => "en" and a fixed ordinal category mapping (1/2/3)
   --  rather than I18N.Plurals. Do not wire it into production; use
   --  Messages.Runtime.
   --
   --  Safely render a validated AST into a structured Result.
   --
   --  Missing variables fail with Missing_Variable. Plural selectors must be
   --  present and numeric. Select selectors are strings. Selectordinal selectors
   --  must be present and numeric. Rendering catches failures and reports them
   --  through Result rather than propagating runtime exceptions.
   --
   --  @param Root First AST node to render. Null renders as the empty string.
   --  @param Args Variable argument map.
   --  @return Structured render result.
   function Render
     (Root : Messages.AST.Node_Access;
      Args : Messages.Arguments.Arguments)
      return Messages.Errors.Result;

end Messages.Render;
