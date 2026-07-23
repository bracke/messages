with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Plural_Render is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "count", "1");
   declare
      One_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Result ("plural one", One_Result);
   end;

   Messages.Arguments.Set (Args, "count", "5");
   declare
      Other_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Result ("plural other", Other_Result);
   end;
end Plural_Render;
