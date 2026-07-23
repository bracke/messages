with Messages.Buffer;
with Messages.Diagnostics;
with Messages.Errors;
with Messages.Observability;
with Messages.Arguments;

--  Internal/test compatibility API for in-tree regression tests.
--
--  This child package is not part of the stable application API. It keeps
--  the single-message, fixed-buffer, and internal-error entry points
--  available for regression and differential tests without exposing them from
--  Messages.Runtime itself.
--
--  Semantics note: this path drives the legacy compiled IR (Messages.Compiler /
--  Messages.Fast_Render), which is locale-agnostic and uses a hardcoded
--  plural/ordinal category mapping. The authoritative public path is
--  Messages.Runtime.Render / Render_Into, which adds locale-aware
--  plural/selectordinal selection through I18N.Plurals. Both share the "only
--  other is mandatory" branch policy. Do not treat the compatibility path as a
--  reference for public rendering semantics.
private package Messages.Runtime.Compatibility is

   --  Initialize the compatibility single-message runtime path.
   --
   --  @param Item Runtime instance to initialize.
   --  @param Source ICU message source to parse, validate, and compile.
   procedure Initialize_Message
     (Item   : in out Runtime;
      Source : String);

   type Execution_Context is record
      Buffer      : aliased Messages.Buffer.Buffer;
      Args        : Messages.Arguments.Arguments;
      Diagnostics : Messages.Diagnostics.Diagnostic_List;
      Metadata    : Messages.Observability.Execution_Metadata;
   end record;

   --  Install the compatibility trace callback.
   --
   --  @param CB Callback to invoke for trace events, or null to disable tracing.
   procedure Set_Trace_Callback
     (CB : Messages.Observability.Trace_Callback);

   --  Render the initialized compatibility message with the supplied arguments.
   --
   --  @param Item Initialized runtime instance.
   --  @param Args Runtime argument map.
   --  @return Internal structured render result for regression tests.
   function Render
     (Item : Runtime;
      Args : Messages.Arguments.Arguments)
      return Messages.Errors.Result;

   --  Render using caller-owned compatibility execution context.
   --
   --  @param Item Initialized runtime instance.
   --  @param Context Caller-owned execution context, buffer, and diagnostics.
   --  @return Internal structured render result for regression tests.
   function Render
     (Item    : Runtime;
      Context : in out Execution_Context)
      return Messages.Errors.Result;

   --  Render into the fixed buffer stored in Context.
   --
   --  @param Item Initialized runtime instance.
   --  @param Context Caller-owned execution context and output buffer.
   --  @return Internal render status for the fixed-buffer path.
   function Render_Into
     (Item    : Runtime;
      Context : in out Execution_Context)
      return Messages.Errors.Status;

   --  Report whether the compatibility single-message runtime has a compiled root.
   --
   --  @param Item Runtime instance to inspect.
   --  @return True when the compatibility message root is initialized.
   function Has_Root
     (Item : Runtime)
      return Boolean;

   --  Return the last deterministic compatibility error.
   --
   --  @param Item Runtime instance to inspect.
   --  @return Last internal error kind recorded by compatibility initialization/rendering.
   function Last_Error
     (Item : Runtime)
      return Messages.Errors.Error_Kind;

end Messages.Runtime.Compatibility;
