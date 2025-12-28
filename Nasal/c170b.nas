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

    # Remove pitot cover
    setprop("/sim/model/c170b/pitot-cover", 0);

    # Setting levers and switches for startup
    setprop("/controls/switches/magnetos", 3);
    setprop("/controls/engines/engine/throttle", 0.15);
    setprop("/controls/engines/engine/mixture", 0.95);
    setprop("/controls/flight/elevator-trim", 0.0);
    setprop("/controls/switches/master-bat", 1);
    setprop("/controls/switches/master-alt", 1);
    setprop("/controls/fuel/fuel-selector", 3);
	setprop("/controls/engines/engine/primer", 3);

    # Setting lights
    setprop("/controls/lighting/nav-lights-switch", 1);
    setprop("/controls/lighting/strobe-switch", 1);
    setprop("/controls/lighting/beacon-switch", 1);

    # Setting flaps to 0
    setprop("/controls/flight/flaps", 0.0);

    # All set, starting engine
    setprop("controls/switches/starter", 1);
    setprop("/engines/engine/auto-start", 1);

    var engine_running_check_delay = 5.0;
    settimer(func {
        if (!getprop("/engines/engine/running")) {
            gui.popupTip("The autostart failed to start the engine. You must lean the mixture and start the engine manually.", 5);
        }
        setprop("controls/switches/starter", 0);
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

############################################
# Static objects: Place
############################################

var StaticModel = {
    new: func (name, file) {
        var m = {
            parents: [StaticModel],
            model: nil,
            model_file: file,
			object_name: name
        };

        setlistener("/sim/" ~ name ~ "/enable", func (node) {
            if (node.getBoolValue()) {
                m.add();
            }
            else {
                m.remove();
            }
        });

        return m;
    },

    add: func {
        var manager = props.globals.getNode("/models", 1);
        var i = 0;
        for (; 1; i += 1) {
            if (manager.getChild("model", i, 0) == nil) {
                break;
            }
        }
        var position = geo.aircraft_position().set_alt(getprop("/position/ground-elev-m"));
        me.model = geo.put_model(me.model_file, position, getprop("/orientation/heading-deg"));
    },

    remove: func {
        if (me.model != nil) {
            me.model.remove();
            me.model = nil;
        }
    }
};

var aircraft_dir = getprop("/sim/aircraft-dir");
StaticModel.new("coneR", aircraft_dir ~ "/Models/Exterior/safety-cone/safety-cone_R.xml");
StaticModel.new("coneL", aircraft_dir ~ "/Models/Exterior/safety-cone/safety-cone_L.xml");
StaticModel.new("gpu", aircraft_dir ~ "/Models/Exterior/external-power/external-power.xml");

# external electrical disconnect when groundspeed higher than 0.1ktn (replace later with distance less than 0.01...)
var ad_timer = maketimer(0.1, func {
    groundspeed = getprop("/velocities/groundspeed-kt") or 0;
    if (groundspeed > 0.1) {
        setprop("/controls/electric/external-power", "false");
    }
});

#following ground equipement stuff placing was only possible by the help of the work by: Melchior Franz, Anders Gidenstam, Detelf Faber, onox. Thanks!
#wheel chocks======================================================

var chocks001_model = {
       index:   0,
       add:   func {
  var manager = props.globals.getNode("/models", 1);
                var i = 0;
                for (; 1; i += 1)
                   if (manager.getChild("model", i, 0) == nil)
                      break;

		var chocks001 = geo.aircraft_position().set_alt(
				props.globals.getNode("/position/ground-elev-m").getValue());

		var aircraft_dir = getprop("/sim/aircraft-dir");
		geo.put_model(aircraft_dir ~ "/Models/Exterior/chocks/LWchocks.ac", chocks001,
				props.globals.getNode("/orientation/heading-deg").getValue());
					 me.index = i;
          },

       remove:   func {
                #print("chocks001_model.remove");
             props.globals.getNode("/models", 1).removeChild("model", me.index);
          },
};

var init_common = func {
	setlistener("/sim/chocks001/enable", func(n) {
		if (n.getValue()) {
				chocks001_model.add();
		} else  {
			chocks001_model.remove();
		}
	});
}
settimer(init_common,0);

var chocks002_model = {
       index:   0,
       add:   func {
  var manager = props.globals.getNode("/models", 1);
                var i = 0;
                for (; 1; i += 1)
                   if (manager.getChild("model", i, 0) == nil)
                      break;

		var chocks002 = geo.aircraft_position().set_alt(
				props.globals.getNode("/position/ground-elev-m").getValue());

		var aircraft_dir = getprop("/sim/aircraft-dir");
		geo.put_model(aircraft_dir ~ "/Models/Exterior/chocks/RWchocks.ac", chocks002,
				props.globals.getNode("/orientation/heading-deg").getValue());
					 me.index = i;
          },

       remove:   func {
                #print("chocks002_model.remove");
             props.globals.getNode("/models", 1).removeChild("model", me.index);
          },
};

var init_common = func {
	setlistener("/sim/chocks002/enable", func(n) {
		if (n.getValue()) {
				chocks002_model.add();
		} else  {
			chocks002_model.remove();
		}
	});
}
settimer(init_common,0);

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

############################################
# Engine coughing sound
############################################

setlistener("/engines/engine[0]/killed", func (node) {
    if (node.getValue() and getprop("/engines/engine[0]/running")) {
        click("coughing-engine-sound", 0.7, 0);
    };
});

############################################
# Flaps movement in 4 steps
############################################

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

# Saved aircraft data is not reliable so save it here as well
aircraft.data.add("/sim/model/c170b/pitot-cover");

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

