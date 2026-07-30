with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Messages.Consistency is

   use Ada.Strings.Unbounded;

   LF : constant Character := Ada.Characters.Latin_1.LF;
   HT : constant Character := Ada.Characters.Latin_1.HT;

   procedure Note
     (Into   : in out Report;
      Kind   : Finding_Kind;
      Locale : String;
      Key    : String;
      Detail : String) is
   begin
      if Into.Count = Max_Findings then
         Into.Overflow := True;
         return;
      end if;

      Into.Count := Into.Count + 1;
      Into.Items (Into.Count) :=
        (Kind   => Kind,
         Locale => To_Unbounded_String (Locale),
         Key    => To_Unbounded_String (Key),
         Detail => To_Unbounded_String (Detail));
   end Note;

   --  A catalog line is "locale.key = value", with the value optionally
   --  quoted. Splitting is done here rather than borrowed from the parser
   --  because this pass must survive lines the parser would reject: a catalog
   --  with one bad line still has translations worth checking.
   procedure Split
     (Line   : String;
      Locale : out Unbounded_String;
      Key    : out Unbounded_String;
      Value  : out Unbounded_String;
      Ok     : out Boolean)
   is
      Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      Dot    : Natural;
   begin
      Locale := Null_Unbounded_String;
      Key    := Null_Unbounded_String;
      Value  := Null_Unbounded_String;
      Ok     := False;

      if Equals = 0 then
         return;
      end if;

      declare
         Left : constant String :=
           Ada.Strings.Fixed.Trim
             (Line (Line'First .. Equals - 1), Ada.Strings.Both);
         Right : constant String :=
           Ada.Strings.Fixed.Trim
             (Line (Equals + 1 .. Line'Last), Ada.Strings.Both);
      begin
         if Left = "" or else Right = "" then
            return;
         end if;

         Dot := Ada.Strings.Fixed.Index (Left, ".");
         if Dot <= Left'First or else Dot = Left'Last then
            return;
         end if;

         Locale := To_Unbounded_String (Left (Left'First .. Dot - 1));
         Key    := To_Unbounded_String (Left (Dot + 1 .. Left'Last));
         Value  :=
           To_Unbounded_String
             (if Right'Length >= 2
                and then Right (Right'First) = '"'
                and then Right (Right'Last) = '"'
              then Right (Right'First + 1 .. Right'Last - 1)
              else Right);
         Ok := True;
      end;
   end Split;

   --  The arguments a message takes, as "{one}{two}" in the order found. Two
   --  messages agree when each takes what the other takes; order and repetition
   --  are a translator's business, so they are normalized away by comparing
   --  membership below.
   function Arguments (Text : String) return String is
      Result : Unbounded_String;
      Index  : Natural := Text'First;
   begin
      while Index <= Text'Last loop
         if Text (Index) = '{' then
            declare
               Close : Natural := 0;
            begin
               for Scan in Index + 1 .. Text'Last loop
                  if Text (Scan) = '}' then
                     Close := Scan;
                     exit;
                  end if;
               end loop;

               exit when Close = 0;
               Append (Result, Text (Index .. Close));
               Index := Close + 1;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
      return To_String (Result);
   end Arguments;

   function Holds (Haystack : String; Needle : String) return Boolean is
   begin
      return Needle /= ""
        and then Ada.Strings.Fixed.Index (Haystack, Needle) /= 0;
   end Holds;

   function Is_Word_Character (Item : Character) return Boolean is
     (Item in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

   --  A token like "install" has to be there as a word: the German for that
   --  command is "installieren", which contains it and is not it, and a user
   --  who types what they were shown gets an error either way. A token that
   --  begins with punctuation -- "--csr", "PKCS#12" -- is matched as it stands,
   --  because a word boundary before a dash means nothing.
   function Holds_Token (Haystack : String; Token : String) return Boolean is
      From : Positive := Haystack'First;
   begin
      if Token = "" then
         return False;
      end if;

      if not Is_Word_Character (Token (Token'First)) then
         return Holds (Haystack, Token);
      end if;

      while From <= Haystack'Last loop
         declare
            At_Index : constant Natural :=
              Ada.Strings.Fixed.Index (Haystack (From .. Haystack'Last), Token);
            Stop : Natural;
         begin
            exit when At_Index = 0;
            Stop := At_Index + Token'Length - 1;

            if (At_Index = Haystack'First
                or else not Is_Word_Character (Haystack (At_Index - 1)))
              and then (Stop = Haystack'Last
                        or else not Is_Word_Character (Haystack (Stop + 1)))
            then
               return True;
            end if;

            From := At_Index + 1;
         end;
      end loop;
      return False;
   end Holds_Token;

   --  ICU reads an apostrophe as the start of a quoted literal when what
   --  follows is one of the characters a pattern is made of. Everywhere else it
   --  is an apostrophe, so only the hazard is reported.
   function Escapes_Something (Text : String) return Boolean is
   begin
      for Index in Text'First .. Text'Last - 1 loop
         if Text (Index) = '''
           and then Text (Index + 1) in '{' | '}' | '#' | '|'
         then
            return True;
         end if;
      end loop;
      return False;
   end Escapes_Something;

   function Word_Count (Text : String) return Natural is
      Count : Natural := 0;
      In_Word : Boolean := False;
   begin
      for Item of Text loop
         if Item = ' ' then
            In_Word := False;
         elsif not In_Word then
            In_Word := True;
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Word_Count;

   procedure Check_Text
     (Source_Name : String;
      Text        : String;
      Verbatim    : Token_Array := No_Tokens;
      Locale_Only : Token_Array := No_Tokens;
      Into        : out Report)
   is
      pragma Unreferenced (Source_Name);

      Default : Unbounded_String := To_Unbounded_String ("en");

      --  The default locale's entries, as LF & key & HT & value & LF. Held as
      --  text rather than a container: this is one pass over a file, and a
      --  catalog large enough for the difference to matter does not exist.
      Originals : Unbounded_String := To_Unbounded_String ("" & LF);

      function Original_For (Key : String) return String is
         Whole : constant String := To_String (Originals);
         Mark  : constant String := LF & Key & HT;
         Start : constant Natural := Ada.Strings.Fixed.Index (Whole, Mark);
         Stop  : Natural;
      begin
         if Start = 0 then
            return "";
         end if;

         Stop :=
           Ada.Strings.Fixed.Index
             (Whole (Start + Mark'Length .. Whole'Last), "" & LF);
         return
           (if Stop = 0 then Whole (Start + Mark'Length .. Whole'Last)
            else Whole (Start + Mark'Length .. Stop - 1));
      end Original_For;

      function Has_Original (Key : String) return Boolean is
      begin
         return Holds (To_String (Originals), LF & Key & HT);
      end Has_Original;

      procedure Each_Line (Handle : not null access procedure (Line : String))
      is
         From : Positive := Text'First;
      begin
         while From <= Text'Last loop
            declare
               Stop : Natural :=
                 Ada.Strings.Fixed.Index (Text (From .. Text'Last), "" & LF);
            begin
               if Stop = 0 then
                  Stop := Text'Last + 1;
               end if;
               Handle (Text (From .. Stop - 1));
               From := Stop + 1;
            end;
         end loop;
      end Each_Line;

      procedure Read_Default (Line : String) is
         Locale, Key, Value : Unbounded_String;
         Ok : Boolean;
      begin
         if Holds (Line, "default_locale") then
            declare
               Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
            begin
               if Equals /= 0 then
                  Default :=
                    To_Unbounded_String
                      (Ada.Strings.Fixed.Trim
                         (Line (Equals + 1 .. Line'Last), Ada.Strings.Both));
               end if;
            end;
            return;
         end if;

         Split (Line, Locale, Key, Value, Ok);
         if Ok and then Locale = Default then
            Append (Originals, To_String (Key) & HT & To_String (Value) & LF);
         end if;
      end Read_Default;

      procedure Check_One (Line : String) is
         Locale, Key, Value : Unbounded_String;
         Ok : Boolean;
      begin
         Split (Line, Locale, Key, Value, Ok);
         if not Ok or else Locale = Default
           or else Holds (Line, "default_locale")
         then
            return;
         end if;

         declare
            L : constant String := To_String (Locale);
            K : constant String := To_String (Key);
            V : constant String := To_String (Value);
         begin
            if not Has_Original (K) then
               --  Unless the caller said this key belongs to a locale rather
               --  than to the default one.
               for Prefix of Locale_Only loop
                  if Ada.Strings.Fixed.Index (K, To_String (Prefix)) = K'First
                  then
                     return;
                  end if;
               end loop;

               Note (Into, Missing_Original, L, K,
                     "no message with this key in " & To_String (Default));
               return;
            end if;

            declare
               Source : constant String := Original_For (K);
               Wanted : constant String := Arguments (Source);
               Got    : constant String := Arguments (V);
               From   : Positive := Wanted'First;
            begin
               --  Each argument the original takes, in the translation.
               while From <= Wanted'Last loop
                  declare
                     Close : Natural := 0;
                  begin
                     for Scan in From .. Wanted'Last loop
                        if Wanted (Scan) = '}' then
                           Close := Scan;
                           exit;
                        end if;
                     end loop;
                     exit when Close = 0;

                     if not Holds (Got, Wanted (From .. Close)) then
                        Note (Into, Argument_Dropped, L, K,
                              "the argument " & Wanted (From .. Close)
                              & " is not in the translation");
                     end if;
                     From := Close + 1;
                  end;
               end loop;

               From := Got'First;
               while From <= Got'Last loop
                  declare
                     Close : Natural := 0;
                  begin
                     for Scan in From .. Got'Last loop
                        if Got (Scan) = '}' then
                           Close := Scan;
                           exit;
                        end if;
                     end loop;
                     exit when Close = 0;

                     if not Holds (Wanted, Got (From .. Close)) then
                        Note (Into, Argument_Added, L, K,
                              "the argument " & Got (From .. Close)
                              & " is not in the original");
                     end if;
                     From := Close + 1;
                  end;
               end loop;

               for Token of Verbatim loop
                  declare
                     T : constant String := To_String (Token);
                  begin
                     if Holds_Token (Source, T)
                       and then not Holds_Token (V, T)
                     then
                        Note (Into, Token_Dropped, L, K,
                              T & " is in the original and not in the"
                              & " translation");
                     end if;
                  end;
               end loop;

               if Escapes_Something (V) then
                  Note (Into, Escape_Hazard, L, K,
                        "an apostrophe here starts a quoted literal and"
                        & " swallows what follows it");
               end if;

               if V = Source and then Word_Count (Source) > 2 then
                  Note (Into, Identical_To_Original, L, K,
                        "word for word the " & To_String (Default) & " text");
               end if;
            end;
         end;
      end Check_One;
   begin
      Into := (Items => [others => <>], Count => 0, Overflow => False);
      Each_Line (Read_Default'Access);
      Each_Line (Check_One'Access);
   end Check_Text;

   procedure Check_File
     (Path        : String;
      Verbatim    : Token_Array := No_Tokens;
      Locale_Only : Token_Array := No_Tokens;
      Into        : out Report)
   is
      File : Ada.Text_IO.File_Type;
      Body_Text : Unbounded_String;
   begin
      Into := (Items => [others => <>], Count => 0, Overflow => False);

      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      exception
         when others =>
            Note (Into, Missing_Original, "", "",
                  "the catalog could not be read: " & Path);
            return;
      end;

      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Body_Text, Ada.Text_IO.Get_Line (File) & LF);
      end loop;
      Ada.Text_IO.Close (File);

      Check_Text (Path, To_String (Body_Text), Verbatim, Locale_Only, Into);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
   end Check_File;

   function Image (Item : Finding) return String is
      Where : constant String :=
        (if Length (Item.Locale) = 0 then To_String (Item.Key)
         else To_String (Item.Locale) & "." & To_String (Item.Key));
   begin
      return Where & ": " & To_String (Item.Detail);
   end Image;

end Messages.Consistency;
