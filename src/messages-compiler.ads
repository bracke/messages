with Messages.AST;
with Messages.Compiled;

private package Messages.Compiler is

   --  Compile a validated AST into the immutable flattened IR.
   --
   --  Scope and semantics (regression-only legacy path):
   --  This compiler and its companion Messages.Fast_Render are an internal pipeline
   --  exercised only through Messages.Runtime.Compatibility and the in-tree
   --  regression suites. They are NOT the stable public render path. Compared
   --  with the authoritative public Messages.Runtime path they are intentionally
   --  legacy:
   --    * select dispatch uses generalized named branches;
   --    * plural/selectordinal category selection is locale-agnostic (one iff
   --      n = 1; ordinal by the literal 1/2/3 mapping), not the locale-aware
   --      I18N.Plurals rules used by the public path.
   --  Both paths do share the "only other is mandatory; absent category branches
   --  fall back to other" branch policy.
   --
   --  The compiler defensively re-runs validation before emitting IR.
   --  Invalid input raises Constraint_Error so normal runtime construction can
   --  continue to report deterministic validation errors before compilation;
   --  so does a message whose Number_Depth exceeds
   --  Messages.Compiled.Max_Number_Depth, which Messages.Cache reports as
   --  Messages.Errors.Nesting_Too_Deep before it compiles.
   --
   --  @param N Root AST node to compile. Null compiles to an empty message.
   --  @return Immutable, limited compiled message handle.
   function Compile
     (N : Messages.AST.Node_Access)
      return Messages.Compiled.Compiled_Message;

   --  How deeply plural and selectordinal blocks nest in a message: the most
   --  of them on any one path from the root into a branch, counting through
   --  select branches (which keep no number of their own) but not counting
   --  them. What Fast_Render's number-context stack must hold.
   --
   --  @param N Root AST node. Null has depth 0.
   --  @return The nesting depth; a message without plurals is 0.
   function Number_Depth
     (N : Messages.AST.Node_Access)
      return Natural;

end Messages.Compiler;
