with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Selectordinal_Render is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   Messages.Arguments.Set (Args, "rank", "1");
   declare
      First_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "rank.label", Args);
   begin
      Example_Support.Print_Result ("ordinal one", First_Result);
   end;

   Messages.Arguments.Set (Args, "rank", "4");
   declare
      Other_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "rank.label", Args);
   begin
      Example_Support.Print_Result ("ordinal other", Other_Result);
   end;

   Messages.Arguments.Set (Args, "rank", "8");
   declare
      Many_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "it", "rank.label", Args);
   begin
      Example_Support.Print_Result ("ordinal many", Many_Result);
   end;
end Selectordinal_Render;
