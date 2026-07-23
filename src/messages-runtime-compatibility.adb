with Ada.Strings.Unbounded;
with Messages.Cache;
with Messages.Compiled;
with Messages.Fast_Render;

package body Messages.Runtime.Compatibility is

   procedure Initialize_Message
     (Item   : in out Runtime;
      Source : String)
   is
      Compiled : Messages.Compiled.Compiled_Message;
   begin
      Finalize (Item);
      declare
         Status : constant Messages.Errors.Result :=
           Messages.Cache.Get_Or_Compile
             (Key     => Source,
              Message => Compiled);
      begin
         if Status.Ok then
            Messages.Compiled.Set_Reference
              (Item.Message, Messages.Compiled.Reference (Compiled));
            Item.Has_Message := True;
            Item.Valid := True;
         else
            Item.Has_Message := False;
            Item.Valid := False;
            Item.Error := Status.Error;
         end if;
      end;
   exception
      when others =>
         Item.Has_Message := False;
         Item.Valid := False;
         Item.Error := Messages.Errors.Parse_Error;
   end Initialize_Message;

   procedure Set_Trace_Callback
     (CB : Messages.Observability.Trace_Callback)
   is
   begin
      Messages.Observability.Set_Trace_Callback (CB);
   end Set_Trace_Callback;

   function Render
     (Item : Runtime;
      Args : Messages.Arguments.Arguments)
      return Messages.Errors.Result
   is
      Buffer : Messages.Buffer.Buffer;
   begin
      if not Item.Valid then
         return Messages.Errors.Failure (Item.Error);
      end if;

      return Messages.Fast_Render.Render
        (Msg    => Item.Message,
         Buffer => Buffer,
         Args   => Args);
   exception
      when others =>
         return Messages.Errors.Failure (Messages.Errors.Parse_Error);
   end Render;

   function Render_Into
     (Item    : Runtime;
      Context : in out Execution_Context)
      return Messages.Errors.Status
   is
   begin
      if not Item.Valid then
         Messages.Diagnostics.Clear (Context.Diagnostics);
         Messages.Diagnostics.Add
           (List    => Context.Diagnostics,
            Kind    => Messages.Errors.To_Diagnostic_Kind (Item.Error),
            Message => "initialization failure");
         return Messages.Errors.Failure_Status (Item.Error);
      end if;

      return Messages.Fast_Render.Render_Into
        (Msg         => Item.Message,
         Buffer      => Context.Buffer,
         Args        => Context.Args,
         Diagnostics => Context.Diagnostics,
         Metadata    => Context.Metadata);
   exception
      when others =>
         Messages.Diagnostics.Clear (Context.Diagnostics);
         Messages.Diagnostics.Add
           (List    => Context.Diagnostics,
            Kind    => Messages.Diagnostics.Parse_Error,
            Message => "runtime exception");
         return Messages.Errors.Failure_Status (Messages.Errors.Parse_Error);
   end Render_Into;

   function Render
     (Item    : Runtime;
      Context : in out Execution_Context)
      return Messages.Errors.Result
   is
      Status : constant Messages.Errors.Status :=
        Render_Into (Item => Item, Context => Context);
   begin
      if not Status.Ok then
         declare
            Result : constant Messages.Errors.Result := Messages.Errors.Failure (Status.Error);
         begin
            return
              (Ok          => Result.Ok,
               Value       => Result.Value,
               Error       => Result.Error,
               Diagnostics => Context.Diagnostics);
         end;
      end if;

      declare
         Value : constant String := Messages.Buffer.To_String (Context.Buffer);
      begin
         return
           (Ok          => True,
            Value       => Ada.Strings.Unbounded.To_Unbounded_String (Value),
            Error       => Messages.Errors.Parse_Error,
            Diagnostics => Context.Diagnostics);
      end;
   end Render;

   function Has_Root
     (Item : Runtime)
      return Boolean
   is
   begin
      return Item.Has_Message
        and then Messages.Compiled.Op_Count (Item.Message) > 0;
   end Has_Root;

   function Last_Error
     (Item : Runtime)
      return Messages.Errors.Error_Kind
   is
   begin
      return Item.Error;
   end Last_Error;

end Messages.Runtime.Compatibility;
