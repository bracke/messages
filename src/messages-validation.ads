with Messages.AST;
with Messages.Errors;

private package Messages.Validation is

   --  Validate a parsed AST before evaluation.
   --
   --  This pass enforces structural integrity: valid identifiers,
   --  mandatory branches, non-null required branch roots, and recursive branch
   --  consistency. It does not inspect runtime argument values.
   --
   --  @param N Root node to validate. Null is valid and represents an empty message.
   --  @return Ok=True when the AST is complete; otherwise Error identifies the issue.
   function Validate
     (N : Messages.AST.Node_Access)
      return Messages.Errors.Result;

end Messages.Validation;
