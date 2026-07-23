with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Equals_In_Value is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "equals.demo", Args);
   begin
      Example_Support.Print_Result ("equals in catalog value", Result);
   end;
end Equals_In_Value;
