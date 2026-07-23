with Ada.Text_IO;
with Messages.Arguments;
with Messages.Diagnostics;
with I18N.Locales;
with Messages.Result;
with Messages.Runtime;

procedure Public_API_Sealed is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
   Locale  : constant I18N.Locales.Locale_Id := "en-US";
begin
   Messages.Diagnostics.Set_Trace_Callback (null);
   Messages.Arguments.Set (Args, "name", "Ada");
   Messages.Runtime.Initialize (Runtime, "examples/catalogs/messages.catalog");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, Locale, "hello", Args);
   begin
      case Result.Status is
         when Messages.Result.Success |
              Messages.Result.Missing_Key |
              Messages.Result.Missing_Argument |
              Messages.Result.Invalid_Argument |
              Messages.Result.Formatting_Error |
              Messages.Result.Execution_Error |
              Messages.Result.Buffer_Overflow |
              Messages.Result.Internal_Error =>
            null;
      end case;

      Ada.Text_IO.Put_Line
        ("public API sealed smoke: "
         & Messages.Result.Render_Status'Image (Result.Status));
   end;

   Messages.Runtime.Finalize (Runtime);
end Public_API_Sealed;
