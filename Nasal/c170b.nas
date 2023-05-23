# =============================== DEFINITIONS ===========================================
# set the update period

var UPDATE_PERIOD = 0.3;

##########################################
# Autostart
##########################################

var autostart = func (msg=1) {
    if (getprop("/engines/engine/running")) {
        if (msg)
            gui.popupTip("Engine already running", 5);
        return;
    }

    # Filling fuel tanks
    setprop("/fdm/jsbsim/propulsion/tank[1]/collector-valve", 1);
    setprop("/fdm/jsbsim/propulsion/tank[2]/collector-valve", 1);

    # Setting levers and switches for startup
    setprop("/controls/switches/magnetos", 3);
    setprop("/controls/engines/engine/throttle", 0.2);
    setprop("/controls/engines/engine/mixture", 0.95);
    setprop("/controls/flight/elevator-trim", 0.0);
    setprop("/controls/switches/master-bat", 1);
    setprop("/controls/switches/master-alt", 1);

    # Setting lights
    setprop("/controls/lighting/nav-lights-switch", 1);
    setprop("/controls/lighting/strobe-switch", 1);
    setprop("/controls/lighting/beacon-switch", 1);

    # Setting flaps to 0
    setprop("/controls/flight/flaps", 0.0);

    # All set, starting engine
    setprop("controls/engines/engine/starter", 1);
    setprop("/engines/engine/auto-start", 1);

    var engine_running_check_delay = 5.0;
    settimer(func {
        if (!getprop("/engines/engine/running")) {
            gui.popupTip("The autostart failed to start the engine. You must lean the mixture and start the engine manually.", 5);
        }
        setprop("controls/engines/engine/starter", 0);
        setprop("/engines/engine/auto-start", 0);
    }, engine_running_check_delay);

};

var reset_system = func {
    if (getprop("/fdm/jsbsim/running")) {
        c170b.autostart(0);
    }
};

var update_pax = func {
    var state = 0;
    state = bits.switch(state, 0, getprop("pax/co-pilot/present"));
    state = bits.switch(state, 1, getprop("pax/left-passenger/present"));
    state = bits.switch(state, 2, getprop("pax/right-passenger/present"));
    state = bits.switch(state, 3, getprop("pax/pilot/present"));
    setprop("/payload/pax-state", state);
};

#Transponder ident light
var ident_status = maketimer(10.0, func {
    setprop("/instrumentation/transponder/ident_status", 1);
});
ident_status.start();

var ident_light_timer = maketimer(0.1, func {
    var light_intensity = getprop("/instrumentation/transponder/ident_light");
    var light_status = getprop("/instrumentation/transponder/ident_light_status");
    var actual_ident = getprop("/instrumentation/transponder/ident_status");

    if ( (light_intensity < 1) and (light_status == 0) and (actual_ident == 1) ) {
       setprop("/instrumentation/transponder/ident_light", light_intensity + 0.1);
       if ( light_intensity > 0.89 ) {
           setprop("/instrumentation/transponder/ident_light_status", 1);
           setprop("/instrumentation/transponder/ident_light", 1);
       }
    }
    else {
       setprop("/instrumentation/transponder/ident_light", light_intensity - 0.1);
       if ( light_intensity < 0.11 ) {
           setprop("/instrumentation/transponder/ident_light_status", 0);
           setprop("/instrumentation/transponder/ident_light", 0);
           setprop("/instrumentation/transponder/ident_status", 0);
       }
    }
});
ident_light_timer.start();

##########################################
# Click Sounds
##########################################

var click = func (name, timeout=0.1, delay=0) {
    var sound_prop = "/sim/model/c170b/sound/click-" ~ name;

    settimer(func {
        # Play the sound
        setprop(sound_prop, 1);

        # Reset the property after 0.2 seconds so that the sound can be
        # played again.
        settimer(func {
            setprop(sound_prop, 0);
        }, timeout);
    }, delay);
};


var flapsDown = func(step) {
    if(step == 0) return;
    if(props.globals.getNode("/sim/flaps") != nil) {
        stepProps("/controls/flight/flaps", "/sim/flaps", step);
        return;
    }
    # Hard-coded flaps movement in 4 equal steps:
    var val = 0.25 * step + getprop("/controls/flight/flaps");
    setprop("/controls/flight/flaps", val > 1 ? 1 : val < 0 ? 0 : val);
}


# ========== primer stuff ======================

# Toggles the state of the primer
var pumpPrimer = func {
    var push = getprop("/controls/engines/engine/primer-lever") or 0;

    if (push) {
        var pump = getprop("/controls/engines/engine/primer") or 0;
        setprop("/controls/engines/engine/primer", pump + 1);
        setprop("/controls/engines/engine/primer-lever", 0);
    }
    else {
        setprop("/controls/engines/engine/primer-lever", 1);
    }
};

# Mixture will be calculated using the primer during 5 seconds AFTER the pilot used the starter
# This prevents the engine to start just after releasing the starter: the propeller will be running
# thanks to the electric starter, but carburator has not yet enough mixture
var primerTimer = maketimer(5, func {
    setprop("/controls/engines/engine/use-primer", 0);
    # Reset the number of times the pilot used the primer only AFTER using the starter
    setprop("/controls/engines/engine/primer", 0);
    print("Primer reset to 0");
    primerTimer.stop();
});

setlistener("/pax/co-pilot/present", update_pax, 0, 0);
setlistener("/pax/left-passenger/present", update_pax, 0, 0);
setlistener("/pax/right-passenger/present", update_pax, 0, 0);
setlistener("/pax/pilot/present", update_pax, 0, 0);
update_pax();

setlistener("/engines/engine/running", func (node) {
    var autostart = getprop("/engines/engine/auto-start");
    var cranking  = getprop("/engines/engine/cranking");
    if (autostart and cranking and node.getBoolValue()) {
        setprop("/controls/engines/engine/starter", 0);
        setprop("/engines/engine/auto-start", 0);
    }
}, 0, 0);

