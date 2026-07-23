with Ada.Text_IO;

package body Example_Support is

   use Messages.Result;
   procedure Print_Result
     (Label  : String;
      Result : Messages.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put (Label & ": ");
      if Result.Status = Messages.Result.Success then
         Put_Line (Messages.Result.Output_Text (Result.Text));
      else
         Put_Line (Messages.Result.Render_Status'Image (Result.Status));
      end if;
   end Print_Result;

   procedure Print_Status
     (Label  : String;
      Result : Messages.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put_Line
        (Label & ": " & Messages.Result.Render_Status'Image (Result.Status));
   end Print_Status;

end Example_Support;
