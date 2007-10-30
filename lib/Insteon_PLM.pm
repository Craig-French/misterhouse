=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_PLM.pm

Description:

	This is the base interface class for Insteon Power Line Modem (PLM)

	For more information regarding the technical details of the PLM:
		http://www.smarthome.com/manuals/2412sdevguide.pdf

Author(s):
    Jason Sharpee
    jason@sharpee.com

License:
    This free software is licensed under the terms of the GNU public license. GPLv2

Usage:
	Use these mh.ini parameters to enable this code:

	Insteon_PLM_serial_port=/dev/ttyS4

    Example initialization:

		$myPLM = new Insteon_PLM("Insteon_PLM");

		#Turn Light Module ID L5 On
		$myPLM->send_plm_cmd(0x0263b900);
		$myPLM->send_plm_cmd(0x0263b280);
	
Notes:

Special Thanks to:
    Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


=cut

use strict;

package Insteon_PLM;

@Insteon_PLM::ISA = ('Serial_Item');

my %Insteon_PLM_Data;

my %plm_commands = (
#PLM Serial Commands
                        plm_info => 0x60,
						plm_reset => 0x67,
                        user_user_reset => 0x55,
						plm_get_config => 0x73,
						plm_set_config => 0x6B,
						plm_led_on => 0x6D,
						plm_led_off => 0x6E,
                        plm_button_event => 0x54,
                        insteon_send => 0x62,
                        insteon_received => 0x50,
                        insteon_ext_received => 0x51,
						insteon_nak => 0x70,
						insteon_ack => 0x71,
                        x10_send => 0x63,
                        x10_received => 0x52,
                        all_link_complete => 0x53,
                        all_link_clean_failed => 0x56,
                        all_link_record => 0x57,
                        all_link_clean_status => 0x58,
                        all_link_send => 0x61,
                        all_link_start => 0x64,
						rf_sleep => 0x72
);

my %x10_house_codes = (
						a => 0x6,
						b => 0xE,
						c => 0x2,
						d => 0xA,
						e => 0x1,
						f => 0x9,
						g => 0x5,
						h => 0xD,
						i => 0x7,
						j => 0xF,
						k => 0x3,
						l => 0xB,
						m => 0x0,
						n => 0x8,
						o => 0x4,
						p => 0xC
);

my %mh_house_codes = (
						'6' => 'a',
						'e' => 'b',
						'2' => 'c',
						'a' => 'd',
						'1' => 'e',
						'9' => 'f',
						'5' => 'g',
						'd' => 'h',
						'7' => 'i',
						'f' => 'j',
						'3' => 'k',
						'b' => 'l',
						'0' => 'm',
						'8' => 'n',
						'4' => 'o',
						'c' => 'p'
);

my %x10_unit_codes = (
						1 => 0x6,
						2 => 0xE,
						3 => 0x2,
						4 => 0xA,
						5 => 0x1,
						6 => 0x9,
						7 => 0x5,
						8 => 0xD,
						9 => 0x7,
						10 => 0xF,
						a => 0xF,
						11 => 0x3,
						b => 0x3,
						12 => 0xB,
						c => 0xB,
						13 => 0x0,
						d => 0x0,
						14 => 0x8,
						e => 0x8,
						15 => 0x4,
						f => 0x4,
						16 => 0xC,
						g => 0xC
						
);

my %mh_unit_codes = (
						'6' => '1',
						'e' => '2',
						'2' => '3',
						'a' => '4',
						'1' => '5',
						'9' => '6',
						'5' => '7',
						'd' => '8',
						'7' => '9',
						'f' => 'a',
						'3' => 'b',
						'b' => 'c',
						'0' => 'd',
						'8' => 'e',
						'4' => 'f',
						'c' => 'g'
);

my %x10_commands = (
						on => 0x2,
						j => 0x2,
						off => 0x3,
						k => 0x3,
						bright => 0x5,
						l => 0x5,
						dim => 0x4,
						m => 0x4,
						preset_dim1 => 0xA,
						preset_dim2 => 0xB,
						all_off => 0x0,
						all_lights_on => 0x1,
						all_lights_off => 0x6,
						status => 0xF,
						status_on => 0xD,
						status_off => 0xE,
						hail_ack => 0x9,
						ext_code => 0x7,
						ext_data => 0xC,
						hail_request => 0x8
);

my %mh_commands = (
						'2' => 'J',
						'3' => 'K',
						'5' => 'L',
						'4' => 'M',
						'a' => 'preset_dim1',
						'b' => 'preset_dim2',
						'0' => 'all_off',
						'1' => 'all_lights_on',
						'6' => 'all_lights_off',
						'f' => 'status',
						'd' => 'status_on',
						'e' => 'status_off',
						'9' => 'hail_ack',
						'7' => 'ext_code',
						'c' => 'ext_data',
						'8' => 'hail_request'
);

sub serial_startup {
   my ($instance) = @_;

   my $port       = $::config_parms{$instance . "_serial_port"};
#   my $speed      = $::config_parms{$instance . "_baudrate"};
	my $speed = 19200;

   $Insteon_PLM_Data{$instance}{'serial_port'} = $port;    
	&::print_log("[Insteon_PLM] serial:$port:$speed");
   &::serial_port_create($instance, $port, $speed,'none','raw');

  if (1==scalar(keys %Insteon_PLM_Data)) {  # Add hooks on first call only
      &::MainLoop_pre_add_hook(\&Insteon_PLM::check_for_data, 1);
   }
}

sub poll_all {

}


sub check_for_data {

   for my $port_name (keys %Insteon_PLM_Data) {
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      my $data = $::Serial_Ports{$port_name}{data};
      if (defined($Insteon_PLM_Data{$port_name}{'obj'}) and !($Insteon_PLM_Data{$port_name}{'obj'}->device_id)
               and !($Insteon_PLM_Data{$port_name}{'obj'}{_id_check})) {
         $Insteon_PLM_Data{$port_name}{'obj'}{_id_check} = 1;
         $Insteon_PLM_Data{$port_name}{'obj'}->send_plm_cmd('0260');
      }
      next if !$data;

	#lets turn this into Hex. I hate perl binary funcs
    my $data = unpack "H*", $data;

#	$::Serial_Ports{$port_name}{data} = undef;
#      main::print_log("PLM $port_name got:$data: [$::Serial_Ports{$port_name}{data}]");
      my $processedNibs;
		$processedNibs = $Insteon_PLM_Data{$port_name}{'obj'}->_parse_data($data);
		
#		&::print_log("PLM Proc:$processedNibs:" . length($data));
      $main::Serial_Ports{$port_name}{data}=pack("H*",substr($data,$processedNibs,length($data)-$processedNibs));
   }
}

sub new {
   my ($class, $port_name, $p_deviceid) = @_;
   $port_name = 'Insteon_PLM' if !$port_name;

   my $self = {};
   $$self{state}     = '';
   $$self{said}      = '';
   $$self{state_now} = '';
   $$self{port_name} = $port_name;
	$$self{last_command} = '';
	$$self{xmit_in_progress} = 0;
	@{$$self{command_stack}} = ();
	@{$$self{command_stack2}} = ();
	$$self{_prior_data_fragment} = '';
   bless $self, $class;
   $Insteon_PLM_Data{$port_name}{'obj'} = $self;
   $self->device_id($p_deviceid) if defined $p_deviceid;

	$$self{xmit_delay} = $::config_parms{Insteon_PLM_xmit_delay};
	$$self{xmit_delay} = 0.125 unless defined $$self{xmit_delay};
	&::print_log("[Insteon_PLM] setting default xmit delay to: $$self{xmit_delay}");
	$$self{xmit_x10_delay} = $::config_parms{Insteon_PLM_xmit_x10_delay};
	$$self{xmit_x10_delay} = 0.5 unless defined $$self{xmit_x10_delay};
	&::print_log("[Insteon_PLM] setting x10 xmit delay to: $$self{xmit_x10_delay}");
	
#   $Insteon_PLM_Data{$port_name}{'send_count'} = 0;
#   push(@{$$self{states}}, 'on', 'off');
#   $self->_poll();

#we just turned on the device, lets wait a bit
#	$self->set_dtr(1);
#   select(undef,undef,undef,0.15);
	
   return $self;
}

sub get_firwmare_version
{
	my ($self) = @_;
	return $self->get_register(10) . $self->get_register(11);
}

sub get_im_configuration
{
	my ($self) = @_;
	return;
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

	my ($package, $filename, $line) = caller;
#	&::print_log("PLM xmit:" , $p_setby->{object_name} . ":$p_state:$p_setby");
	
	#identify the type of device that sent the request
	if (
		$p_setby->isa("X10_Item") or 
		$p_setby->isa("X10_Switchlinc") or
		$p_setby->isa("X10_Appliance")
		)
	{
		$self->_xlate_mh_x10($p_state,$p_setby);
	} elsif ($p_setby->isa("Insteon_Link")) {
		$self->send_plm_cmd('0261' . $p_state);
	} elsif ($p_setby->isa("Insteon_Device")) {
		$self->send_plm_cmd('0262' . $p_state);
	} else {
		$self->_xlate_mh_x10($p_state,$p_setby);
	}
}

sub initiate_linking_as_responder
{
	my ($self, $group) = @_;

	# it is not clear that group should be anything as the group will be taken from the controller
	$group = '01' unless $group;
	# set up the PLM as the responder
	my $cmd = '0264'; # start all linking
	$cmd .= '00'; # responder code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
	$self->send_plm_cmd($cmd);
}

sub initiate_linking_as_controller
{
	my ($self, $group) = @_;

	$group = 'FF' unless $group;
	# set up the PLM as the responder
	my $cmd = '0264'; # start all linking
	$cmd .= '01'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
	$self->send_plm_cmd($cmd);
}


sub cancel_linking
{
	my ($self) = @_;
	$self->send_plm_cmd('0265');
}

sub send_plm_cmd
{
	my ($self, $cmd) = @_;
	#queue any new commands
	if (defined $cmd and $cmd ne '')
	{
#		&::print_log("PLM Add Command:" . $cmd . ":XmitInProgress:" . $$self{xmit_in_progress} . ":" );
		my %cmd_record = {};
		$cmd_record{cmd} = $cmd;
		$cmd_record{queue_time} = $::Time;
#		unshift(@{$$self{command_stack}},$cmd);
		unshift(@{$$self{command_stack2}},\%cmd_record);

	}
	#we dont transmit on top of another xmit
	if ($$self{xmit_in_progress} != 1) {
		$$self{xmit_in_progress} = 1;
		#TODO: Should start a timer just in case PLM is not responding and we need to clear xmit_in_progress after a while.
		#always send the oldest command first
#		$cmd = pop(@{$$self{command_stack}});
		my $cmdptr = pop(@{$$self{command_stack2}});
		my %cmd_record = {};
		if ($cmdptr) {
			%cmd_record = %$cmdptr;
			$cmd = $cmd_record{cmd};
		} else {
			$cmd = '';
		}
		if (defined $cmd and $cmd ne '') 
		{
			#put the command back into the stack.. Its not our job to tamper with this array
#			push(@{$$self{command_stack}},$cmd);
			push(@{$$self{command_stack2}},\%cmd_record) if %cmd_record;
			return $self->_send_cmd($cmd);
		}
	} else {
		return;
	}
}

sub _send_cmd {
	my ($self, $cmd) = @_;
	my $instance = $$self{port_name};

#	&::print_log("PLM: Executing command:$cmd:") unless $main::config_parms{no_log} =~/Insteon_PLM/;
	my $data = pack("H*",$cmd);
	$main::Serial_Ports{$instance}{object}->write($data);
### Dont overrun the controller.. Its easy, so lets wait a bit
#	select(undef,undef,undef,0.15);
    #X10 is sloooooow
	# however, the ack/nack processing seems to allow some comms (notably insteon) to proceed
	# much faster--hence the ability to overide the slow default of 0.5 seconds
	my $delay = $$self{xmit_delay};
	if (substr($cmd,0,4) eq '0263') { # is x10; so, be slow
		$delay = $$self{xmit_x10_delay};
	}
	if ($delay) {
		select(undef,undef,undef,$delay);
	}
   	$$self{'last_change'} = $main::Time;
}


sub _parse_data {
	my ($self, $data) = @_;
   my ($name, $val);

	my $processedNibs=0;

	# it is possible that a fragment exists from a previous attempt; so, if it exists, prepend it
	if ($$self{_data_fragment}) {
		&::print_log("[Insteon_PLM] Prepending prior data fragment: $$self{_data_fragment}");
		$$self{_prior_data_fragment} = $$self{_data_fragment};
		$data = $$self{_data_fragment} . $data;
		$$self{_data_fragment} = undef;
	}
	&::print_log( "[Insteon_PLM] Parsing serial data: $data") if $main::Debug{insteon};

	# begin by pulling out any PLM ack/nacks
	my $prev_cmd = ''; #lc(pop(@{$$self{command_stack}}));
	my $cmdptr = pop(@{$$self{command_stack2}});
	my %cmd_record = {};
	if ($cmdptr) {
		%cmd_record = %$cmdptr;
		$prev_cmd = lc $cmd_record{cmd};
	}
	my $residue_data = '';
	my $process_next_command = 0;
	if (defined $prev_cmd and $prev_cmd ne '') 
	{
#		&::print_log("PLM: Defined:$prev_cmd");
		my $ackcmd = $prev_cmd . '06';
		my $nackcmd = $prev_cmd . '15';
		foreach my $data_1 (split(/($ackcmd)|($nackcmd)|(0260\w{12}06)|(0260\w{12}15)/,$data))
		{
			#ignore blanks.. the split does odd things
			next if $data_1 eq '';

			if ($data_1 =~ /^($ackcmd)|($nackcmd)|(0260\w{12}06)|(0260\w{12}15)$/) {
				$processedNibs+=length($data_1);
				my $ret_code = substr($data_1,length($data_1)-2,2);
#				&::print_log("PLM: Return code $ret_code");
				if ($ret_code eq '06') {
					if (substr($data_1,0,4) eq '0260') {
						$self->device_id(substr($data_1,4,6));
						$self->firmware(substr($data_1,14,2));
						&::print_log("[Insteon_PLM] PLM id: " . $self->device_id . 
							" firmware: " . $self->firmware)
							if $main::Debug{insteon};
					}
					# command succeeded
#					&::print_log("PLM: Command succeeded: $data_1.");
					$$self{xmit_in_progress} = 0;
					$process_next_command = 1;
#					select(undef,undef,undef,.15);
#					$self->process_command_stack();
				} elsif ($ret_code eq '15') { #NAK Received
					&::print_log("[Insteon_PLM] Interface extremely busy.");
					# abort until retry limit is implemented
					# TO-DO: limit # of retries
#					push(@{$$self{command_stack}}, $prev_cmd);
					$$self{xmit_in_progress} = 0;
					$process_next_command = 1;
#					$self->process_command_stack();			
				} else {
					# We have a problem (Usually we stepped on another X10 command)
					&::print_log("[Insteon_PLM] Command error: $data_1.");
					$$self{xmit_in_progress} = 0;
					#move it off the top of the stack and re-transmit later!
					#TODO: We should keep track of an errored command and kill it if it fails twice.  prevent an infinite loop here
					$process_next_command = 1;
#					$self->process_command_stack();
				}
			} else {
				$residue_data .= $data_1;
			}			
		}
	} else {
		$residue_data = $data;
	}


	foreach my $data_1 (split(/(0263\w{6})|(0252\w{4})|(0250\w{18})|(0251\w{46})|(0261\w{6})|(0253\w{16})|(0256\w{8})|(0257\w{16})|(0258\w{2})/,$residue_data))
	{
		#ignore blanks.. the split does odd things
		next if $data_1 eq '';
		#we found a matching command in stream, add to processed bytes
		$processedNibs+=length($data_1);

		if (substr($data_1,0,4) eq '0250') { #Insteon Standard Received
			$$self{_data_fragment} = $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0251') { #Insteon Extended Received
			$$self{_data_fragment} = $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0252') { #X10 Received
			&::process_serial_data($self->_xlate_x10_mh($data_1));	
		} elsif (substr($data_1,0,4) eq '0253') { #ALL-Linking Completed
			&::print_log("[Insteon_PLM] ALL-Linking Completed:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0256') { #ALL-Link Cleanup Failure Report
			&::print_log("[Insteon_PLM] ALL-Link Cleanup Failure Report:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0257') { #ALL-Link Record Response
			&::print_log("[Insteon_PLM] ALL-Link Record Response:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0258') { #ALL-Link Cleanup Status Report
			&::print_log("[Insteon_PLM] ALL-Link Cleanup Status Report:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0261') { #ALL-Link Broadcast 
			&::print_log("[Insteon_PLM] ALL-Link Broadcast:$data_1") if $main::Debug{insteon};
#			$$self{_data_fragment} = $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,2) eq '15') { #NAK Received
			&::print_log("[Insteon_PLM] Interface extremely busy.");
			#retry after slight delay; perhaps this is better handled w/ a timer?
			select(undef,undef,undef,0.15);
			$$self{xmit_in_progress} = 0;
			$self->process_command_stack();			
		} else {
			#for now anything not recognized, kill pending xmission
			# NOOOO - it's probably a fragment; so, handle it
			$$self{_data_fragment} = $data_1 unless $data_1 eq $$self{_prior_data_fragment};
#			&::print_log("[Insteon_PLM] WARNING!! An insteon message with message: $data_1 " 
#				. "was received.  Aborting current transmission in progress");
#			$$self{xmit_in_progress} = 0;
			#drop latest
#			pop(@{$$self{command_stack}});				
			
		}
	}

	if ($process_next_command) {
		select(undef,undef,undef,.15);
		$self->process_command_stack();
	}

	return $processedNibs;
}

sub process_command_stack
{
	my ($self) = @_;
	## send any remaining commands in stack
	my $stack_count = @{$$self{command_stack2}};
#			&::print_log("UPB Command stack2:$stack_count:@{$$self{command_stack}}:");
	if ($stack_count> 0 ) 
	{
		#send any remaining commands.
		$self->send_plm_cmd();
	}			
}

sub _xlate_mh_x10
{
        my ($self,$p_state,$p_setby) = @_;

	my $msg;
	my $cmd=$p_state;
        $cmd=~ s/\:.*$//;
        $cmd=lc($cmd);

	my $id=lc($p_setby->{id_by_state}{$cmd});

	my $hc = lc(substr($p_setby->{x10_id},1,1));
	my $uc = lc(substr($p_setby->{x10_id},2,1));

	if ($hc eq undef) {
		&::print_log("[Insteon_PLM] Object:$p_setby Doesnt have an x10 id (yet)");
		return undef;
	}

	#Every X10 message starts with the House and unit code
	$msg = "02";
	$msg.= unpack("H*",pack("C",$plm_commands{x10_send}));
	$msg.= substr(unpack("H*",pack("C",$x10_house_codes{substr($id,1,1)})),1,1);
	$msg.= substr(unpack("H*",pack("C",$x10_unit_codes{substr($id,2,1)})),1,1);
	$msg.= "00";
	$self->send_plm_cmd($msg);

	my $ecmd;
	#Iterate through the rest of the pairs of nibbles
	for (my $pos = 3; $pos<length($id); $pos++) {
		$msg= "02";
		$msg.= unpack("H*",pack("C",$plm_commands{x10_send}));
		$msg.= substr(unpack("H*",pack("C",$x10_house_codes{substr($id,$pos,1)})),1,1);
		$pos++;

		#look for an explicit command
		$ecmd = substr($id,$pos,length($id)-$pos);
#		&::print_log("PLM:PAIR:$id:$pos:$ecmd:");
		if (defined $x10_commands{$ecmd} )
		{
			$msg.= substr(unpack("H*",pack("C",$x10_commands{$ecmd})),1,1);
			$pos+=length($id)-$pos-1;
		} else {
			$msg.= substr(unpack("H*",pack("C",$x10_commands{substr($id,$pos,1)})),1,1);			
		}
		$msg.= "80";
		$self->send_plm_cmd($msg);
	}
}

sub _xlate_x10_mh
{
	my ($self,$data) = @_;

	my $msg=undef;
	if (uc(substr($data,length($data)-2,2)) eq '00')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_unit_codes{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
#		&::print_log("PLM: X10 address:$data:$msg:");
	} elsif (uc(substr($data,length($data)-2,2)) eq '80')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_commands{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
#		&::print_log("PLM: X10 command:$data:$msg:");
	}
	
#&::print_log("PLM:2XMH:$data:$msg:");
	return $msg;
}

sub delegate
{
	my ($self,$p_data) = @_;

	my $data = substr($p_data,4,length($p_data)-4);
	my %msg = &Insteon_Device::_xlate_insteon_mh($data);
	if (%msg) {
		&::print_log ("[Insteon_PLM] DELEGATE:$msg{source}:$msg{destination}:$data:") if $main::Debug{insteon};
	
		# get the matching object
		my $object = $self->get_object($msg{source}, $msg{group});
		&::print_log("[Insteon_PLM] Warn! Unable to locate object for source: $msg{source} and group; $msg{group}")
			if (!(defined $object));
		if (defined $object) {
			&::print_log("[Insteon_PLM] Processing message for " . $object->get_object_name);
			$object->_process_message($self, %msg);
			return 1;
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}

sub get_object
{
	my ($self, $p_deviceid, $p_group) = @_;

	my $retObj = undef;

	for my $obj (@{$$self{objects}})
	{
		#Match on Insteon objects only
		if ($obj->isa("Insteon_Device"))
		{
			if (lc $obj->device_id() eq $p_deviceid)
			{
				if ($p_group)
				{
					if ($p_group eq $obj->group)
					{
						$retObj = $obj;
						last;
					}
				} else {
					$retObj = $obj;
					last;
				}
			}
		}
	}

	return $retObj;
}


sub add_id_state
{
	my ($self,$id,$state) = @_;
#	&::print_log("PLM: AddIDSTATE:$id:$state");
}

sub add
{
	my ($self,@p_objects) = @_;

	my @l_objects;

	for my $l_object (@p_objects) {
		if ($l_object->isa('Group_Item') ) {
			@l_objects = $$l_object{members};
			for my $obj (@l_objects) {
				$self->add($obj);
			}
		} else {
		    $self->add_item($l_object);
		}
	}
}

sub add_item
{
    my ($self,$p_object) = @_;

#    $p_object->tie_items($self);
    push @{$$self{objects}}, $p_object;
	#request an initial state from the device
	if (!($p_object->isa('Insteon_Link')) and $p_object->isa('Insteon_Device')) 
	{
		# don't request status for objects associated w/ other than the primary group 
		#    as they are psuedo links	
		my $scan_at_startup = $::config_parms{Insteon_PLM_scan_at_startup};
		$scan_at_startup = 1 unless defined $scan_at_startup;
		$p_object->request_status($p_object) if $p_object->group eq '01' and $scan_at_startup;
	}
	return $p_object;
}

sub remove_all_items {
   my ($self) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
 #        $_->untie_items($self);
      }
   }
   delete $self->{objects};
}

sub add_item_if_not_present {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
         if ($_ eq $p_object) {
            return 0;
         }
      }
   }
   $self->add_item($p_object);
   return 1;
}

sub remove_item {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      for (my $i = 0; $i < scalar(@{$$self{objects}}); $i++) {
         if ($$self{objects}->[$i] eq $p_object) {
            splice @{$$self{objects}}, $i, 1;
 #           $p_object->untie_items($self);
            return 1;
         }
      }
   }
   return 0;
}


sub is_member {
    my ($self, $p_object) = @_;

    my @l_objects = @{$$self{objects}};
    for my $l_object (@l_objects) {
	if ($l_object eq $p_object) {
	    return 1;
	}
    }
    return 0;
}

sub find_members {
	my ($self,$p_type) = @_;

	my @l_found;
	my @l_objects = @{$$self{objects}};
	for my $l_object (@l_objects) {
		if ($l_object->isa($p_type)) {
			push @l_found, $l_object;
		}
	}
	return @l_found;
}

sub device_id {
	my ($self, $p_deviceid) = @_;
	$$self{deviceid} = $p_deviceid if defined $p_deviceid;
	return $$self{deviceid};
}

sub get_device 
{
	my ($self, $p_deviceid, $p_group) = @_;
	foreach my $device ($self->find_members('Insteon_Device')) {
		if ($device->device_id eq $p_deviceid and $device->group eq $p_group) {
			return $device;
		}
	}
}

sub firmware {
	my ($self, $p_firmware) = @_;
	$$self{firmware} = $p_firmware if defined $p_firmware;
	return $$self{firmware};
}

=begin
sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut
1;
