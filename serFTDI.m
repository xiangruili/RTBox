function out = serFTDI(cmd, h, param) %#ok
% out = serFTDI('cmd', h, param)
% 
% This works like IOPort from PTB, while it uses the ftd2xx driver. The
% advantages include fast and convenient port mapping and LatencyTimer control.
% The write function has better timing than Windows WriteFile(). The
% inconvenience is that the driver is exclusive with VCP driver under OSX and
% Linux. For now, to use this driver, one must unload or uninstall VCP driver
% for OSX and Linux.
% 
% Under Linux, VCP driver can be unloaded temporarily by:
%  sudo rmmod ftdi_sio
% After the USB is re-plugged, the VCP driver will be on again.
% If FTDI VCP is not used by other devices, it can be blacklisted by:
%  sudo gedit /etc/modprobe.d/blacklist.conf
%  Add following line, save and reboot:
%  blacklist ftdi_sio
% To avoid running Matlab as sudo, a udev rules file like 
%  /etc/udev/rules.d/ftd2xx.rules
% with the following content needs to be created with sudo:
%  SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666"
% 
% Under OSX, the temporary way to unload Apple's VCP driver is:
%  sudo kextunload -b com.apple.driver.AppleUSBFTDI
% This will be effective until the next reboot or reload VCP driver by:
%  sudo kextload -b com.apple.driver.AppleUSBFTDI
% Under OSX, if the VCP driver is not needed, it can be disabled by:
%  cd /System/Library/Extensions/
%  sudo mv AppleUSBFTDI.kext AppleUSBFTDI.disabled
%  sudo touch /System/Library/Extensions
% If FTDI VCP driver is installed, it may be at following folder:
%  cd /Library/Extensions
%  sudo mv FTDIUSBSerialDriver.kext FTDIUSBSerialDriver.disabled
%  sudo touch /Library/Extensions
% 
% The following commands are available for serFTDI.
% 
% nPorts = serFTDI('NumberOfPorts') 
% - Return the number of connected FTDI ports. 
% 
% haveAccess = serFTDI('Accessible') 
% - Check if serFTDI can access to the ports. This returns true if there is no
% port, otherwise it tries if the driver can open a port. If it returns false,
% it is likely due to VCP driver is present under OSX/Linux.
% 
% [h, errmsg] = serFTDI('Open', index, cfgStr)
% - Open a serial port, and return the handle (h=index) which will be used by
% other serFTDI commands. The input index can be 0 through nPorts-1. If the
% second output, errmsg, is requested, the Open command won't throw error even
% if it fails to open a port. Instead it will return -1 as invalid handle, and 
% store error message in the errmsg. The errmsg will be empty with success.
% 
% The optional input cfgStr is in format of 
% 'BaudRate=115200 ReceiveTimeout=0.3 LatencyTimer=0.002'. 
% The default for other parameters are 
% 'DataBits=8 StopBits=1 FlowControl=None Parity=None SendTimeout=0.3'.
% Invalid or unsupported parameters will be ignored silently.
% 
% serFTDI('Configure', h, cfgStr)
% - Allow to configure above parameters after Open. See serFTDI('Open') for
% the parameters for cfgStr.
% 
% nBytes = serFTDI('BytesAvailable', h)
% - Return the number of bytes in the receive buffer.
% 
% [tPre, tPost] = serFTDI('Write', h, data, blocking)
% - Write data, normally uint8 or char, to the port. Return the time before and
% after serial write. The 4th input, blocking, default 1, asks blocking write,
% which makes tPost meaningful.
%
% [data, tPost] = serFTDI('Read', h, nBytes) 
% - Read bytes from the port, and return row-vector data in double. The optional
% nBytes, if provided, informs the driver to read at most nBytes bytes. The Read
% will return if there are no enough bytes after ReceiveTimeout. If nBytes is
% not provided, the data currently in the buffer will be read.
% 
% The optional second output, tPost, is the timestamp after reading the data.
% 
% serFTDI('Purge', h)
% - Purge both receive and transmit buffers.
% 
% serFTDI('Flush', h)
% - Purge the transmit buffer only.
% 
% [tPre, ub] = serFTDI('SetDTR', h, duration)
% - Set the Data Terminal Ready (DTR) line. duration (default infinity) is the
% seconds for DTR signal to stay. For example 
%  serFTDI('SetDTR', h, 0.005) % output 5 ms TTL at DTR line
% The optional output are the time of the DTR onset, and its upper bound.
% 
% serFTDI('ClrDTR', h)
% - Clear the Data Terminal Ready (DTR) line.
% 
% [tPre, ub] = serFTDI('SetRTS', h, duration)
% - Set the Request To Send (RTS) control signal. duration (default infinity) is
% the seconds for RTS signal to stay. The output are the time of the RTS onset,
% and its upper bound.
% 
% serFTDI('ClrRTS', h)
% - Clear the Request To Send (RTS) control signal.
% 
% serFTDI('Close', h)
% - Close the port.
% 
% serFTDI('CloseAll')
% - Close all open ports. 'clear serFTDI' will do the same.
% 
% oldTimer = serFTDI('LatencyTimer', h, newTimer)
% - Set and/or query LatencyTimer. The optional newTimer input and oldTimer
% output are from 0.001 to 0.255 seconds with 1 millisecond step. Like other
% parameters, the timer will be reset after a port is Open.
% 
% oldVal = serFTDI('Verbosity', newVal)
% - Set and/or query verbosity. The default is 0, meaning the screen output is
% suppressed. If it is non-zero, the port parameters and other information will 
% be shown when Open or Configure a port.
% 
% oldState = serFTDI('Lock', newState) 
% - Set and/or query mex lock state. If the optional newState is true, this will
% lock serFTDI into memory, so 'clear all' won't clear it. Note this is for
% special purpose, so use it with care.
% 
% st = serFTDI('Version')
% - Query version information. The returned struct has field of 'version',
% 'module' (serFTDI) and 'authors' (xiangrui.li@gmail.com).
% 
% See also: IOPort, serIO

% 171001 First mex compile (xiangrui.li@gmail.com)
% 171008 Write this help, also make functionSignatures.json usable
