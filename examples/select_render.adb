with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Select_Render is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "animal", "male");
   declare
      Cat_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "pet.label", Args);
   begin
      Example_Support.Print_Result ("select male", Cat_Result);
   end;

   Messages.Arguments.Set (Args, "animal", "unknown");
   declare
      Other_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "pet.label", Args);
   begin
      Example_Support.Print_Result ("select fallback branch", Other_Result);
   end;
end Select_Render;
