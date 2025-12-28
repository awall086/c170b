#Electrical System
var electricsystem=func{
    var master_bat = getprop("/controls/switches/master-bat");
    var master_alt = getprop("/controls/switches/master-alt");
	var battery_status = getprop("/systems/electrical/battery-status");
	var new_battery_status = battery_status;
	var external_volts = 0;
	var external_amps = 0;

	# external power source connected
    if (getprop("/controls/electric/external-power"))
    {
        external_volts = 14;
        external_amps = 35; 
 }
	
	var engine_rpm = getprop("/engines/engine/rpm");
	var ideal_rpm = 720;	
	var ideal_volts = 12;
	var ideal_amps = 35;
	var bus_load = 0;
	var factor = engine_rpm/ideal_rpm;
	if (factor > 1.0) {
		factor = 1.0;
	}


	var alternator_volts = ideal_volts * factor;
	var alternator_amps = ideal_amps * factor;
 
       if ( master_alt == 0 ){
 		var alternator_volts = 0;
		var alternator_amps = 0;
	}


    # determine power source
    	var bus_volts = 0.0;
		var battery_volts = (12.0 * battery_status)/100;
		var battery_amps = (26.0 * battery_status)/100;
    	var power_source = nil;	


    if ( master_bat ) {
        bus_volts = battery_volts;        
		power_source = "battery";
    }
    if ( master_alt and (alternator_volts > bus_volts) ) {
        bus_volts = alternator_volts;
		bus_load += alternator_amps;
        power_source = "alternator";
    }
    if ( master_bat and (external_volts > bus_volts ) ) {
        bus_volts = external_volts;
		bus_load += external_amps;
        power_source = "external";
    }

    if ( power_source == "battery" ) {
		new_battery_status = battery_status - 0.0001;
		bus_load += battery_amps;
	}

    if ( ( power_source == "alternator" or power_source == "external" ) and ( battery_status < 100.0 ) ) {
		new_battery_status = battery_status + 0.0001;
	}
		
    # Comm-Nav
    if ( getprop("/controls/circuit-breakers/radio1") ) {
        setprop("/systems/electrical/outputs/comm[0]", bus_volts);
        setprop("/systems/electrical/outputs/nav", bus_volts);
        setprop("/systems/electrical/outputs/audio-panel", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/comm[0]", 0.0);
        setprop("/systems/electrical/outputs/nav", 0.0);
        setprop("/systems/electrical/outputs/audio-panel", 0.0);
    }

    # Transponder
    if ( getprop("/controls/circuit-breakers/flaps") ) {
        setprop("/systems/electrical/outputs/transponder", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/transponder", 0.0);
    }

    # Instrument Power: ignition, fuel, oil temperature
    if ( getprop("/controls/circuit-breakers/instr") ) {
        setprop("/systems/electrical/outputs/instr-ignition-switch", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/instr-ignition-switch", 0.0);
    }
 
	# starter
    if ( bus_volts > 8 ) {
		if ( getprop("controls/switches/starter") ) {
			setprop("systems/electrical/outputs/starter", bus_volts);
        } else {
            setprop("systems/electrical/outputs/starter", 0.0);
            }
        } else {
            setprop("systems/electrical/outputs/starter", 0.0);
	}
	
    # Interior lights
    if ( getprop("/controls/circuit-breakers/instr_lt") ) {
        setprop("/systems/electrical/outputs/instrument-lights", bus_volts);
        setprop("/systems/electrical/outputs/cabin-lights", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/instrument-lights", 0.0);
        setprop("/systems/electrical/outputs/cabin-lights", 0.0);
    }    

    # Autopilot Power
    if ( getprop("/controls/circuit-breakers/autopilot") ) {
        setprop("/systems/electrical/outputs/autopilot", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/autopilot", 0.0 );
    }

    # Landing Light Power
    if ( getprop("/controls/circuit-breakers/landing_lt") ) {
        setprop("/systems/electrical/outputs/landing-light", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/landing-light", 0.0 );
    }    
        
    # Taxi Lights Power
    # Notice taxi lights also use landing lights breaker. It is not a bug.
    if ( getprop("/controls/circuit-breakers/landing_lt") ) {
        setprop("/systems/electrical/outputs/taxi-light", bus_volts); 
 } else {
        setprop("/systems/electrical/outputs/taxi-light", 0.0);
    }

    # Beacon Power
    if ( getprop("/controls/circuit-breakers/beacon") ) {
        setprop("/systems/electrical/outputs/beacon-light", bus_volts);		
		if ( getprop("/controls/lighting/beacon-switch") ) {
			bus_load -= bus_volts / 2.4;
		}
	} else {
        setprop("/systems/electrical/outputs/beacon-light", 0.0);
    }
    
    # Nav Lights Power
    if ( getprop("/controls/circuit-breakers/nav_lt") ) {
        setprop("/systems/electrical/outputs/nav-lights", bus_volts);
		if ( getprop("/controls/lighting/nav-lights-switch") ) {
			bus_load -= bus_volts / 2.4;
		}
    } else {
        setprop("/systems/electrical/outputs/nav-lights", 0.0);
    }

    # Strobe Lights Power
    if ( getprop("/controls/circuit-breakers/strobe_lt") ) {
        setprop("/systems/electrical/outputs/strobe-lights", bus_volts); 
 } else {
        setprop("/systems/electrical/outputs/strobe-lights", 0.0);
    }

    # Turn Coordinator and directional gyro Power
    if ( getprop("/controls/circuit-breakers/turn-coordinator") ) {
        setprop("/systems/electrical/outputs/turn-coordinator", bus_volts);
        setprop("/systems/electrical/outputs/DG", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/turn-coordinator", 0.0);
        setprop("/systems/electrical/outputs/DG", 0.0);
    }

	setprop("/systems/electrical/suppliers/battery", battery_volts);
	setprop("/systems/electrical/suppliers/alternator", alternator_volts);
	setprop("/systems/electrical/amps", alternator_amps);
	setprop("/systems/electrical/bus_load", bus_load);
	setprop("/systems/electrical/volts", bus_volts);
	setprop("/systems/electrical/battery-status", new_battery_status);

	settimer(electricsystem, 0);
}

setlistener("sim/signals/fdm-initialized", electricsystem);



