with Messages.Buffer;
with Messages.Compiled;
with Messages.Diagnostics;
with Messages.Errors;
with Messages.Observability;
with Messages.Arguments;

private package Messages.Fast_Render is

   --  Regression-only legacy renderer. This executes the compiled IR for the
   --  in-tree compatibility/differential tests. It is locale-agnostic and
   --  supports generalized select branches plus a hardcoded plural/ordinal
   --  category mapping (one iff n = 1; ordinal by 1/2/3). The stable public
   --  render path is Messages.Runtime with locale-aware I18N.Plurals selection.
   --  Both share the "only other is mandatory; absent category branches fall
   --  back to other" policy.

   --  Render a compiled message into caller-owned fixed output storage and
   --  return only status metadata. This is the strict no-result-
   --  materialization path.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg    : Messages.Compiled.Compiled_Message;
      Buffer : in out Messages.Buffer.Buffer;
      Args   : Messages.Arguments.Arguments)
      return Messages.Errors.Status;

   --  Render into caller-owned storage while collecting bounded structured
   --  diagnostics. Diagnostics storage is caller-owned and preallocated.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @param Diagnostics Caller-owned preallocated diagnostic list.
   --  @param Metadata Caller-owned execution metadata used for start-event trace context.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg         : Messages.Compiled.Compiled_Message;
      Buffer      : in out Messages.Buffer.Buffer;
      Args        : Messages.Arguments.Arguments;
      Diagnostics : in out Messages.Diagnostics.Diagnostic_List;
      Metadata    : Messages.Observability.Execution_Metadata)
      return Messages.Errors.Status;

   --  Convenience overload for callers that do not provide execution metadata.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @param Diagnostics Caller-owned preallocated diagnostic list.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg         : Messages.Compiled.Compiled_Message;
      Buffer      : in out Messages.Buffer.Buffer;
      Args        : Messages.Arguments.Arguments;
      Diagnostics : in out Messages.Diagnostics.Diagnostic_List)
      return Messages.Errors.Status;

   --  Render a compiled message using caller-owned fixed output storage.
   --
   --  Evaluation is a linear program-counter loop over precompiled operations.
   --  Branch operations jump directly to precomputed target indexes and never
   --  traverse AST nodes. The render loop writes only to Buffer and stack-local
   --  state.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @return Structured render result.
   function Render
     (Msg    : Messages.Compiled.Compiled_Message;
      Buffer : in out Messages.Buffer.Buffer;
      Args   : Messages.Arguments.Arguments)
      return Messages.Errors.Result;

   --  Compatibility wrapper for callers that do not manage buffers directly.
   --  The wrapper creates a stack-local fixed buffer.
   --
   --  @param Msg Compiled message to render.
   --  @param Args Runtime argument map.
   --  @return Structured render result.
   function Render
     (Msg  : Messages.Compiled.Compiled_Message;
      Args : Messages.Arguments.Arguments)
      return Messages.Errors.Result;

end Messages.Fast_Render;
