program SRHotkey;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  Winapi.Windows,
  Winapi.Messages;

const
  ntdll = 'ntdll.dll';
  PROCESS_SUSPEND_RESUME = $0800;

function NtSuspendProcess(ProcessHandle: THandle): LongWord; stdcall;
  external ntdll name 'NtSuspendProcess';
function NtResumeProcess(ProcessHandle: THandle): LongWord; stdcall;
  external ntdll name 'NtResumeProcess';

type
  KBDLLHOOKSTRUCT = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

  PKBDLLHOOKSTRUCT = ^KBDLLHOOKSTRUCT;

var
  Hook: HHOOK;
  WinPressed: Boolean = False;
  HotKeySuspend: Cardinal = VK_F10;
  HotKeyResume: Cardinal = VK_F11;
  Process: THandle;

procedure PrintHelp;
begin
  writeln;
  writeln('Sets hotkeys to suspend/resume processes. Copyright (C) 2018 diversenok');
  writeln;
  writeln('Usage: SRHotkey [PID] [[Suspend Hotkey]] [[Resume Hotkey]]');
  writeln(' Parameters:');
  writeln('  PID => Process ID to suspend/resume');
  writeln('  Suspend Hotkey => Optional key kode. Default is 121 (aka F10)');
  writeln('  Resume Hotkey => Optional key kode. Default is 122 (aka F11)');
  writeln(' Note:');
  writeln('  These hotkeys shoud be used in combination with Winkey: Win+F10 & Win+F11');
  Halt(ERROR_INVALID_PARAMETER);
end;

function HookProc(nCode: Integer; wParam: wParam; lParam: lParam): LRESULT; stdcall;
var
  Key: Cardinal;
begin
  if nCode = HC_ACTION then
  begin
    Key := PKBDLLHOOKSTRUCT(lParam).vkCode;
    if Key = VK_LWIN then
      case wParam of
        WM_KEYDOWN:
          WinPressed := True;
        WM_KEYUP:
          WinPressed := False;
      end;
    if WinPressed and (wParam = WM_KEYDOWN) then
    begin
      if Key = HotKeySuspend then
      begin
        writeln('Suspending');
        NtSuspendProcess(Process);
      end
      else if Key = HotKeyResume then
      begin
        writeln('Resuming');
        NtResumeProcess(Process);
      end;
    end;
  end;
  Result := CallNextHookEx(Hook, nCode, wParam, lParam);
end;

procedure HookAndWait;
var
  msg: TMsg;
begin
  Hook := SetWindowsHookEx(WH_KEYBOARD_LL, HookProc, GetModuleHandle(nil), 0);
  if Hook = 0 then
  begin
    writeln('Unable to set hook');
    Halt(ERROR_HOOK_NOT_INSTALLED);
  end;
  writeln('You can minimize this window now. To exit press Ctrl+C.');
  while GetMessage(msg, 0, 0, 0) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
  UnhookWindowsHookEx(Hook);
  CloseHandle(Hook);
  CloseHandle(Process);
end;

var
  PID: Cardinal;
  err: Integer;

begin
  if ParamCount = 0 then
    PrintHelp;
  if ParamCount = 3 then
  begin
    Val(ParamStr(2), HotKeySuspend, err);
    if err <> 0 then
    begin
      writeln('Suspend Hotkey should be integer.');
      Halt(ERROR_INVALID_PARAMETER);
    end;
    Val(ParamStr(3), HotKeyResume, err);
    if err <> 0 then
    begin
      writeln('Resume Hotkey should be integer.');
      Halt(ERROR_INVALID_PARAMETER);
    end;
  end;
  if ParamCount >= 1 then
  begin
    Val(ParamStr(1), PID, err);
    if err <> 0 then
      PrintHelp;
    Process := OpenProcess(PROCESS_SUSPEND_RESUME, False, PID);
    if Process = 0 then
    begin
      writeln('Unable to open process.');
      Halt(ERROR_ACCESS_DENIED);
    end;
  end;
  HookAndWait;
end.
