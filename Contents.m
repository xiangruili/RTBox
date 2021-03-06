% USTC Response Time Box Toolbox
% 
%  FindSerialPorts.m        - Return serial port names on computer
%  ftd2xx.dll               - FTDI D2XX dynamic library for Windows 
%  FTDIPorts.m              - Return FTDI serial ports for serIO('Open')
%  functionSignatures.json  - Useuful for tab compeletion under later Matlab
%  KbEventClass.m           - Basice keyboard function, called by RTBox.m etc
%  libftd2xx.*              - FTDI D2XX dynamic library for OSX and Linux 
%  MACAddress_mex.mex*      - Return MAC address for Windows
%  ReadKey.m                - Obsolete, use KbEventClass instead
%  RTBox.m                  - Driver to control USTC RTBox
%  RTBoxADC.m               - Driver to RTBox as analog-to-digital converter
%  RTBoxADCDemo.m           - Demo: use RTBoxADC to measure light signal
%  RTBoxAsKeypad.m          - Set RTBox hardware as a keypad
%  RTBoxCheckUpdate.m       - Update driver code and firmware from website
%  RTBoxClass.m             - Driver (object-oriented) to control RTBox
%  RTBoxClass_demo.m        - Demo: show how to use RTBoxClass.m
%  RTBoxdemo.m              - Demo: measure RT to light flash
%  RTBoxdemo_audio.m        - Demo: measure RT to a sound
%  RTBoxdemo_EEG.m          - Demo: using TTL to indicate EEG event type
%  RTBoxdemo_EEGfMRI.m      - Demo: for EEG+MRI recording
%  RTBoxdemo_eyetracker.m   - Notes for how to use TTL for DNI eye tracker
%  RTBoxdemo_lightTrigger.m - Demo: measure RT using light trigger
%  RTBoxdemo_Orientation.m  - Demo: measure RT to gabor orientation
%  RTBoxes.m                - Driver to use multiple boxes
%  RTBoxFirmwareUpdate.m    - Update RTBox firmware
%  RTBoxPorts.m             - Return port names for RTBoxes
%  RTBoxSimple.m            - Use RTBox in simple mode
%  RTBoxSimpleDemo.m        - Demo: using RTBox in simple mode
%  RTBoxSyncTest.m          - Test clock synchronization
%  serFTDI.m                - Help text for serFTDI mex files
%  serFTDI.mex*             - serFTDI mex files for different OS
%  serIO.m                  - Wrapper function to call serFTDI or IOPort
%  subFuncHelp.m            - Show help text for a sub-command
%  WaitTill.m               - Obsolete, use KbEventClass instead
