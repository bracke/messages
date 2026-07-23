with Ada.Text_IO;
with Example_Support;
with Messages.Arguments;
with Messages.Diagnostics;
with Messages.Result;
with Messages.Runtime;

procedure Diagnostics_Inspection is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   --  Intentionally omit the required "name" argument so the example shows
   --  diagnostics attached to an error result.
   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("render status", Result);

      Ada.Text_IO.Put_Line
        ("has missing-variable diagnostic: "
         & Boolean'Image
             (Messages.Diagnostics.Has_Kind
                (Result.Diagnostics,
                 Messages.Diagnostics.Missing_Variable)));

      Ada.Text_IO.Put_Line
        ("diagnostic count:" & Natural'Image (Messages.Diagnostics.Length (Result.Diagnostics)));

      for Index in 1 .. Messages.Diagnostics.Length (Result.Diagnostics) loop
         declare
            Item : constant Messages.Diagnostics.Diagnostic :=
              Messages.Diagnostics.Element (Result.Diagnostics, Index);
         begin
            Ada.Text_IO.Put_Line
              ("diagnostic"
               & Positive'Image (Index)
               & ": "
               & Messages.Diagnostics.Diagnostic_Kind'Image (Item.Kind)
               & " key="
               & Messages.Diagnostics.Key_Text (Item)
               & " message="
               & Messages.Diagnostics.Message_Text (Item));
         end;
      end loop;
   end;
end Diagnostics_Inspection;
