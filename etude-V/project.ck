// Homework 4 - Real-time Synthesis with Logistic Map
// Mouse/trackpad gestural input with chaotic pattern generation

// HID Input Setup
Hid hi;
HidMsg msg;

0 => int device;

if(!hi.openMouse(device)) me.exit();

float mouseX, mouseY, mouseW;
0.5 => mouseX;
0.5 => mouseY;
0.5 => mouseW;

// Logistic Map Class
class Logistic {
    float _x, _r;
    false => int isSet;

    fun void set(float x, float r) {
        x => _x;
        r => _r;
        true => isSet;
    }

    fun float tick() {
        if(!isSet) me.exit();
        (_r * _x) * (1.0 - _x) => _x;
        return _x;
    }

    fun void setR(float r) {
        r => _r;
    }

    fun void reset(float x) {
        x => _x;
    }
}

Logistic map;
map.set(0.7, 3.5);

// Audio Signal Chain
Pan2 pan;

pan.chan(0) => NRev revLeft => dac.chan(0);
pan.chan(1) => PRCRev revRight => dac.chan(1);

revLeft.mix(0.09);
revRight.mix(0.09);

SinOsc sin => pan;
PulseOsc pul => pan;
SqrOsc sqr => pan;
TriOsc tri => pan;
SawOsc saw => pan;

// Envelope Setup
35::ms => dur updateRate;

Step unity => Envelope freqEnv => blackhole;
Step unity2 => Envelope ampEnv => blackhole;
Step unity3 => Envelope timbreEnv => blackhole;
Step unity4 => Envelope chaosEnv => blackhole;

1.0 => unity.next;
1.0 => unity2.next;
1.0 => unity3.next;
1.0 => unity4.next;

freqEnv.duration(updateRate);
ampEnv.duration(updateRate);
timbreEnv.duration(updateRate);
chaosEnv.duration(updateRate);

220.0 => freqEnv.target;
0.25 => ampEnv.target;
3.5 => chaosEnv.target;
0.0 => timbreEnv.target;

// Start Concurrent Processes
spork ~ updateFromGestures();
spork ~ updateChaos();
spork ~ updateOscillators();

1::eon => now;

// Gesture Input Processing
fun void updateFromGestures() {
    while(true) {
        hi => now;

        while(hi.recv(msg)) {
            if(msg.isMouseMotion()) {
                msg.scaledCursorX => mouseX;
                1.0 - msg.scaledCursorY => mouseY;

                2.8 + (mouseX * 1.2) => float r;
                chaosEnv.target(r);

                Std.mtof(mouseY * 48 + 36) => float baseFreq;
                freqEnv.target(baseFreq);
            }
            else if(msg.isButtonDown()) {
                if(msg.which == 1) {
                    pan.gain(0.0);
                }
            }
            else if(msg.isButtonUp()) {
                if(msg.which == 1) {
                    pan.gain(1.0);
                }
            }
            else if(msg.isWheelMotion()) {
                if(msg.deltaY) {
                    msg.deltaY / 10.0 +=> mouseW;
                    if(mouseW > 1.0) 1.0 => mouseW;
                    if(mouseW < -1.0) -1.0 => mouseW;

                    (mouseW + 1.0) / 2.0 => float amp;
                    if(amp >= 0.0 && amp <= 1.0) {
                        ampEnv.target(amp * 0.5);
                    }
                }
            }
        }
    }
}

// Chaotic Pattern Generation
fun void updateChaos() {
    while(true) {
        map.setR(chaosEnv.last());
        map.tick() => float chaosValue;
        timbreEnv.target(chaosValue * 2.0 - 1.0);
        updateRate => now;
    }
}

// Oscillator Bank Updates
fun void updateOscillators() {
    while(true) {
        freqEnv.last() => float baseFreq;
        ampEnv.last() => float amp;
        timbreEnv.last() => float timbre;

        sin.freq(0.0 + baseFreq);
        pul.freq(0.5 + baseFreq);
        sqr.freq(1.7 + baseFreq);
        tri.freq(2.1 + baseFreq);
        saw.freq(2.4 + baseFreq);

        sin.gain(amp * panTimbre(timbre, 0.0));
        pul.gain(amp * panTimbre(timbre, 1.0));
        sqr.gain(amp * panTimbre(timbre, 2.0));
        tri.gain(amp * panTimbre(timbre, 3.0));
        saw.gain(amp * panTimbre(timbre, 4.0));

        1::samp => now;
    }
}

// Timbre Panning Function
fun float panTimbre(float x, float y) {
    Math.sin(x * 5.0 + y * 0.3) => float tmp;
    pan.pan(tmp);
    (1.0 + tmp) / 2.0 => tmp;
    0.15 *=> tmp;
    return tmp;
}
