with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Invalid_Argument is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "count", "not-a-number");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Status ("invalid numeric argument", Result);
   end;
end Invalid_Argument;
