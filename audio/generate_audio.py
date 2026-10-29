"""Original deterministic procedural game audio. Python standard library only.
All oscillators, noise and envelopes are synthesized here; no sampled material.
Run from any directory to regenerate the mono 22050 Hz PCM WAVs beside this file.
"""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parent
RATE = 22050
TAU = math.tau
RNG = random.Random(783041)

def render(name, seconds, sample, peak=.65, fade=True):
    n = round(RATE*seconds)
    values = [sample(i/RATE, i, n) for i in range(n)]
    if fade:
        edge = min(round(RATE*.003), n//10)
        for i in range(edge):
            values[i] *= i/edge
            values[-1-i] *= i/edge
    scale = peak / max(1e-9, max(abs(v) for v in values))
    data = b''.join(struct.pack('<h', round(max(-1, min(1,v*scale))*32767)) for v in values)
    with wave.open(str(OUT/name), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(data)
    print(f'{name:14s} {seconds:5.2f}s peak {peak:.2f} ({20*math.log10(peak):5.1f} dBFS)')

# High-passed noise coupled to a descending chirp produces a weighty blade sweep.
previous = [0.0]
def swing(t,i,n):
    white=RNG.uniform(-1,1)
    hp=white-previous[0]; previous[0]=white
    x=t/.22
    env=math.sin(math.pi*x)**1.7
    return env*(.5*hp + .24*math.sin(TAU*(850*t-1450*t*t)))
render('swing.wav', .22, swing, .54)

# A punchy low body, noisy crack and a little metallic after-ring.
def hit(t,i,n):
    return (.85*math.exp(-28*t)*math.sin(TAU*(112*t-100*t*t))
        + .6*RNG.uniform(-1,1)*math.exp(-60*t)
        + .19*math.sin(TAU*631*t)*math.exp(-22*t)
        + .1*math.sin(TAU*917*t)*math.exp(-26*t))
render('hit.wav', .23, hit, .76)

# Short upward rubbery pulse, never a cartoon whistle.
def jump(t,i,n):
    env=math.sin(math.pi*min(1,t/.24))**1.1*math.exp(-8*t)
    phase=TAU*(110*t+670*t*t)
    return env*(math.sin(phase)+.22*math.sin(phase*2))
render('jump.wav', .24, jump, .48)

low=[0.0]
def dash(t,i,n):
    white=RNG.uniform(-1,1)
    low[0]=.78*low[0]+.22*white
    env=(1-math.exp(-200*t))*math.exp(-16*t)
    return env*(1.2*low[0]+.28*math.sin(TAU*(85*t-85*t*t)))
render('dash.wav', .29, dash, .52)

# Crunch and scattered little woody/metallic debris ticks.
ticks=[(.03,610),(.067,841),(.103,530),(.161,713),(.225,1120)]
def prop(t,i,n):
    v=.7*RNG.uniform(-1,1)*math.exp(-22*t)+.6*math.sin(TAU*73*t)*math.exp(-15*t)
    for start,freq in ticks:
        dt=t-start
        if dt>=0:
            v += .16*math.sin(TAU*freq*dt)*math.exp(-85*dt)
    return v
render('prop.wav', .43, prop, .65)

# Distorted descending low pulse to distinguish player damage from enemy hits.
def hurt(t,i,n):
    phase=TAU*(144*t-140*t*t)
    buzz=math.tanh(2.2*(math.sin(phase)+.16*math.sin(phase*3)))
    env=(1-math.exp(-200*t))*math.exp(-10*t)
    return env*(buzz+.20*RNG.uniform(-1,1))
render('hurt.wav', .38, hurt, .61)

# Three clear rising notes with soft harmonics and a warm root underneath.
notes=[(0,220),(.18,277.1826),(.36,329.6276),(.58,440)]
def win(t,i,n):
    v=0
    for start,f in notes:
        dt=t-start
        if dt>=0:
            e=(1-math.exp(-80*dt))*math.exp(-3.6*dt)
            v+=e*(math.sin(TAU*f*dt)+.24*math.sin(TAU*2*f*dt)+.08*math.sin(TAU*3*f*dt))
    return v*min(1,(1.6-t)/.2)
render('win.wav', 1.6, win, .57)

# Every carrier and modulator makes an integer number of cycles in 10 seconds.
# Thus the waveform and its slope repeat exactly at the loop boundary.
LENGTH=10.0
partials=[(47.0,.36,.7),(59.9,.28,1.1),(70.2,.15,.1),(94.0,.10,2.7),
          (119.8,.075,1.8),(141.1,.045,.3),(281.9,.022,2.0)]
def ambience(t,i,n):
    v=0
    for k,(freq,amp,phase) in enumerate(partials):
        drift=.12*math.sin(TAU*(k%3+1)*t/LENGTH+k)
        trem=.83+.17*math.sin(TAU*(k%2+1)*t/LENGTH+phase)
        v+=amp*trem*math.sin(TAU*freq*t+phase+drift)
    return v
render('ambience.wav', LENGTH, ambience, .10, fade=False)
