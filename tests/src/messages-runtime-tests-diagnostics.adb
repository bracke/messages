with AUnit.Assertions;

with Messages.Diagnostics; use Messages.Diagnostics;
with Messages.Errors; use Messages.Errors;
with Messages.Observability; use Messages.Observability;
with Messages.Runtime.Compatibility;
with Messages.Arguments;

package body Messages.Runtime.Tests.Diagnostics is

   Max_Trace : constant Positive := 16;

   Trace_Events         :
     array (1 .. Max_Trace) of Messages.Observability.Trace_Event_Kind :=
       [others => Messages.Observability.Message_End];
   Trace_Count          : Natural := 0;
   First_Trace_Key      :
     String (1 .. Messages.Observability.Message_Key_Capacity) :=
       [others => Character'Val (0)];
   First_Trace_Key_Last : Natural := 0;

   procedure Reset_Trace is
   begin
      Trace_Count := 0;
      Trace_Events := [others => Messages.Observability.Message_End];
      First_Trace_Key := [others => Character'Val (0)];
      First_Trace_Key_Last := 0;
   end Reset_Trace;

   procedure Capture_Trace
     (Event : Messages.Observability.Trace_Event_Kind; Key : String) is
   begin
      if Trace_Count < Max_Trace then
         Trace_Count := Trace_Count + 1;
         Trace_Events (Trace_Count) := Event;
         if Trace_Count = 1 and then Key'Length > 0 then
            First_Trace_Key_Last :=
              Natural'Min (Key'Length, First_Trace_Key'Length);
            First_Trace_Key (1 .. First_Trace_Key_Last) :=
              Key (Key'First .. Key'First + First_Trace_Key_Last - 1);
         end if;
      end if;
   end Capture_Trace;

   function Captured_First_Key return String is
   begin
      if First_Trace_Key_Last = 0 then
         return "";
      end if;

      return First_Trace_Key (1 .. First_Trace_Key_Last);
   end Captured_First_Key;

   procedure Raising_Trace
     (Event : Messages.Observability.Trace_Event_Kind; Key : String)
   is
      pragma Unreferenced (Event, Key);
   begin
      raise Constraint_Error with "intentional trace failure";
   end Raising_Trace;

   procedure Add_Arg
     (Args : in out Messages.Arguments.Arguments; Key : String; Value : String) is
   begin
      Messages.Arguments.Set (Args => Args, Key => Key, Value => Value);
   end Add_Arg;

   procedure Test_Output_Unchanged_With_Trace
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Args, "name", "Ada");

      Messages.Runtime.Compatibility.Set_Trace_Callback (null);
      declare
         Without_Trace : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         Reset_Trace;
         Messages.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
         declare
            With_Trace : constant Messages.Errors.Result :=
              Messages.Runtime.Compatibility.Render (Runtime, Args);
         begin
            Messages.Runtime.Compatibility.Set_Trace_Callback (null);

            AUnit.Assertions.Assert
              (Condition => Without_Trace.Ok and then With_Trace.Ok,
               Message   => "both traced and untraced renders should succeed");
            AUnit.Assertions.Assert
              (Condition =>
                 Messages.Errors.Value_Text (Without_Trace)
                 = Messages.Errors.Value_Text (With_Trace),
               Message   => "trace callback must not change render output");
            AUnit.Assertions.Assert
              (Condition => Messages.Errors.Value_Text (With_Trace) = "Hello Ada",
               Message   =>
                 "expected rendered output should remain unchanged");
         end;
      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Output_Unchanged_With_Trace;

   procedure Test_Missing_Variable_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Parse_Error_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Missing_Branch_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Trace_Order (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Concurrent_Diagnostics_Are_Context_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Diagnostic_List_Overflow_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Metadata_Uses_Fixed_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Callback_Exception_Is_Non_Intrusive
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Metadata_Message_Key_Reaches_Start_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N observability/diagnostics tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Output_Unchanged_With_Trace'Access,
         "trace callback does not alter rendered output");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Variable_Diagnostic'Access,
         "missing variable produces structured diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Parse_Error_Diagnostic'Access,
         "invalid ICU produces parse diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Branch_Diagnostic'Access,
         "missing branch produces structured diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Trace_Order'Access,
         "trace events appear start to ops to end");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Concurrent_Diagnostics_Are_Context_Local'Access,
         "concurrent diagnostics stay in caller-owned contexts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Diagnostic_List_Overflow_Is_Bounded'Access,
         "diagnostic list overflow remains bounded and visible");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Metadata_Uses_Fixed_Storage'Access,
         "execution metadata uses fixed storage and truncates deterministically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Callback_Exception_Is_Non_Intrusive'Access,
         "trace callback exceptions do not affect rendering");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Metadata_Message_Key_Reaches_Start_Event'Access,
         "execution metadata message key reaches message start trace event");
   end Register_Tests;

   procedure Test_Missing_Variable_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Context);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              not Result.Ok
              and then Result.Error = Messages.Errors.Missing_Variable,
            Message   =>
              "missing variable should fail render deterministically");
         AUnit.Assertions.Assert
           (Condition =>
              Messages.Diagnostics.Has_Kind
                (Result.Diagnostics, Messages.Diagnostics.Missing_Variable),
            Message   => "missing variable diagnostic should be present");
         AUnit.Assertions.Assert
           (Condition =>
              Messages.Diagnostics.Key_Text
                (Messages.Diagnostics.Element (Result.Diagnostics, 1))
              = "name",
            Message   =>
              "missing variable diagnostic should include variable key");

      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Missing_Variable_Diagnostic;

   procedure Test_Parse_Error_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => not Result.Ok,
            Message   =>
              "invalid ICU should fail render through stored init error");
         AUnit.Assertions.Assert
           (Condition =>
              Messages.Diagnostics.Has_Kind
                (Result.Diagnostics, Messages.Diagnostics.Parse_Error),
            Message   => "parse diagnostic should be present for invalid ICU");

      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Parse_Error_Diagnostic;

   procedure Test_Missing_Branch_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "{gender, select, male {He}}");
      Add_Arg (Args, "gender", "other");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => not Result.Ok,
            Message   =>
              "missing required branch should fail deterministically");
         AUnit.Assertions.Assert
           (Condition =>
              Messages.Diagnostics.Has_Kind
                (Result.Diagnostics, Messages.Diagnostics.Missing_Branch),
            Message   => "missing branch diagnostic should be present");

      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Missing_Branch_Diagnostic;

   procedure Test_Trace_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "Hello {name}, {count, plural, one {# file} other {# files}}");
      Add_Arg (Args, "name", "Ada");
      Add_Arg (Args, "count", "2");

      Reset_Trace;
      Messages.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         Messages.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then Messages.Errors.Value_Text (Result) = "Hello Ada, 2 files",
            Message   => "traced plural render should succeed");
         AUnit.Assertions.Assert
           (Condition => Trace_Count >= 5,
            Message   =>
              "trace should contain start, several operations, and end");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (1) = Messages.Observability.Message_Start,
            Message   => "first trace event should be message start");
         AUnit.Assertions.Assert
           (Condition =>
              Trace_Events (Trace_Count) = Messages.Observability.Message_End,
            Message   => "last trace event should be message end");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (2) = Messages.Observability.Op_Text,
            Message   => "first operation should be text");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (3) = Messages.Observability.Op_Variable,
            Message   => "second operation should be variable");

      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Trace_Order;

   procedure Test_Concurrent_Diagnostics_Are_Context_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime  : Messages.Runtime.Runtime;
      Failures : array (1 .. 4) of Boolean := [others => False] with Atomic_Components;

      task type Worker is
         entry Start (Index : Positive);
      end Worker;

      task body Worker is
         Id      : Positive := 1;
         Context : Messages.Runtime.Compatibility.Execution_Context;
      begin
         accept Start (Index : Positive) do
            Id := Index;
         end Start;

         declare
            Result : constant Messages.Errors.Result :=
              Messages.Runtime.Compatibility.Render (Runtime, Context);
         begin
            if Result.Ok
              or else
                not Messages.Diagnostics.Has_Kind
                      (Result.Diagnostics, Messages.Diagnostics.Missing_Variable)
              or else
                Messages.Diagnostics.Key_Text
                  (Messages.Diagnostics.Element (Result.Diagnostics, 1))
                /= "name"
            then
               Failures (Id) := True;
            end if;
         end;
      exception
         when others =>
            Failures (Id) := True;
      end Worker;

   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Messages.Runtime.Compatibility.Set_Trace_Callback (null);

      declare
         Workers : array (1 .. 4) of Worker;
      begin
         for Index in Workers'Range loop
            Workers (Index).Start (Index);
         end loop;
      end;

      for Index in Failures'Range loop
         AUnit.Assertions.Assert
           (Condition => not Failures (Index),
            Message   =>
              "worker"
              & Integer'Image (Index)
              & " should have local diagnostics");
      end loop;

      Messages.Runtime.Finalize (Runtime);
   end Test_Concurrent_Diagnostics_Are_Context_Local;

   procedure Test_Diagnostic_List_Overflow_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      List : Messages.Diagnostics.Diagnostic_List;
   begin
      for Index in 1 .. Messages.Diagnostics.Max_Diagnostics + 3 loop
         Messages.Diagnostics.Add
           (List    => List,
            Kind    => Messages.Diagnostics.Missing_Variable,
            Message => "missing variable" & Integer'Image (Index),
            Key     => "name");
      end loop;

      AUnit.Assertions.Assert
        (Condition =>
           Messages.Diagnostics.Length (List) = Messages.Diagnostics.Max_Diagnostics,
         Message   => "diagnostic list length must remain fixed at capacity");
      AUnit.Assertions.Assert
        (Condition =>
           Messages.Diagnostics.Element (List, Messages.Diagnostics.Max_Diagnostics)
             .Kind
           = Messages.Diagnostics.Overflow_Warning,
         Message   => "last diagnostic should report bounded overflow");
      AUnit.Assertions.Assert
        (Condition =>
           Messages.Diagnostics.Key_Text
             (Messages.Diagnostics.Element
                (List, Messages.Diagnostics.Max_Diagnostics))
           = "diagnostics",
         Message   =>
           "overflow diagnostic should identify diagnostics capacity");
   end Test_Diagnostic_List_Overflow_Is_Bounded;

   procedure Test_Metadata_Uses_Fixed_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Metadata : Messages.Observability.Execution_Metadata;
      Long_Key :
        constant String (1 .. Messages.Observability.Message_Key_Capacity + 8) :=
          (others => 'k');
   begin
      Messages.Observability.Set_Message_Key (Metadata, Long_Key);
      Messages.Observability.Set_Locale (Metadata, "en");
      Metadata.Depth := 3;

      declare
         Stored_Key    : constant String :=
           Messages.Observability.Message_Key (Metadata);
         Stored_Locale : constant String :=
           Messages.Observability.Locale (Metadata);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Stored_Key'Length = Messages.Observability.Message_Key_Capacity,
            Message   =>
              "message key metadata should truncate to fixed capacity");
         AUnit.Assertions.Assert
           (Condition => Stored_Locale = "en",
            Message   =>
              "locale metadata should round-trip from fixed storage");
         AUnit.Assertions.Assert
           (Condition => Metadata.Depth = 3,
            Message   =>
              "metadata depth should remain caller-owned execution state");
      end;
   end Test_Metadata_Uses_Fixed_Storage;

   procedure Test_Callback_Exception_Is_Non_Intrusive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Args, "name", "Ada");

      Messages.Runtime.Compatibility.Set_Trace_Callback (Raising_Trace'Access);
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         Messages.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "Hello Ada",
            Message   =>
              "raising trace callback must not change render result");
      end;

      Messages.Runtime.Finalize (Runtime);
   exception
      when others =>
         Messages.Runtime.Compatibility.Set_Trace_Callback (null);
         Messages.Runtime.Finalize (Runtime);
         raise;
   end Test_Callback_Exception_Is_Non_Intrusive;

   procedure Test_Metadata_Message_Key_Reaches_Start_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Context.Args, "name", "Ada");
      Messages.Observability.Set_Message_Key (Context.Metadata, "greeting");

      Reset_Trace;
      Messages.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Context);
      begin
         Messages.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "Hello Ada",
            Message   => "metadata-backed render should succeed");
         AUnit.Assertions.Assert
           (Condition =>
              Trace_Count > 0
              and then Trace_Events (1) = Messages.Observability.Message_Start,
            Message   => "first event should be message start");
         AUnit.Assertions.Assert
           (Condition => Captured_First_Key = "greeting",
            Message   =>
              "message key metadata should be passed to start event");
      end;

      Messages.Runtime.Finalize (Runtime);
   exception
      when others =>
         Messages.Runtime.Compatibility.Set_Trace_Callback (null);
         Messages.Runtime.Finalize (Runtime);
         raise;
   end Test_Metadata_Message_Key_Reaches_Start_Event;

end Messages.Runtime.Tests.Diagnostics;
