with Ada.Text_IO;
with Messages.Arguments;
with Messages.Result; use Messages.Result;
with Messages.Runtime;

procedure Public_API_Example is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, "examples/catalogs/messages.catalog");
   Messages.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "hello",
           Arguments => Args);
   begin
      if Result.Status = Messages.Result.Success then
         Ada.Text_IO.Put_Line
           ("public API render: "
            & Messages.Result.Output_Text (Result.Text));
      else
         Ada.Text_IO.Put_Line
           ("public API render status: "
            & Messages.Result.Render_Status'Image (Result.Status));
      end if;
   end;
end Public_API_Example;
