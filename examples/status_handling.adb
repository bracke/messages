with Ada.Text_IO;
with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Status_Handling is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;

   procedure Explain
     (Label  : String;
      Result : Messages.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put (Label & ": ");
      case Result.Status is
         when Messages.Result.Success =>
            Put_Line ("success => " & Messages.Result.Output_Text (Result.Text));
         when Messages.Result.Missing_Key =>
            Put_Line ("message key not found after locale fallback");
         when Messages.Result.Missing_Argument =>
            Put_Line ("required render argument was not supplied");
         when Messages.Result.Invalid_Argument =>
            Put_Line ("argument text could not be interpreted for branch selection");
         when Messages.Result.Formatting_Error =>
            Put_Line ("validated message could not be formatted");
         when Messages.Result.Execution_Error =>
            Put_Line ("runtime or catalog is invalid");
         when Messages.Result.Buffer_Overflow =>
            Put_Line ("internal fixed render buffer was too small");
         when Messages.Result.Internal_Error =>
            Put_Line ("unexpected internal failure was contained");
      end case;
   end Explain;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "name", "Ada");
   Explain
     ("success status",
      Messages.Runtime.Render (Runtime, "en", "hello", Args));

   Messages.Arguments.Clear (Args);
   Explain
     ("missing argument status",
      Messages.Runtime.Render (Runtime, "en", "hello", Args));

   Explain
     ("missing key status",
      Messages.Runtime.Render (Runtime, "en", "no.such.key", Args));
end Status_Handling;
