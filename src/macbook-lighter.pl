#!/usr/bin/env perl
#
# This is a script to automatically adjust Macbook Air (2012) screen and keyboard
# backlight brightness using the built in light sensor.
#
#  Author: Janis Jansons (Janhouse) - janis.jansons@janhouse.lv
#  
#
# Dependencies: notify-send, Macbook Air (applesmc module), listed perl modules.
#

use warnings;
use strict;
use POSIX;
use Scalar::Util qw(looks_like_number);

use IO::Async::Stream;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use Time::HiRes qw(usleep); 

############################### Configuration starts here ######################

#  Delay between checks in seconds.
my $check_interval=7;

# Debug mode 0/1.
my $debug=0; 

# Path to lock file.
# If the file contains word 'locked', script does nothing.
my $applock_file="/tmp/.apple_sensor.txt"; 

# Max light (sensor resolution).
my $light_max=255;

# Path for light sensor.
my $sensor="/sys/devices/platform/applesmc.768/light";


# Stuff for screen backlight.
# Bottom range of light ammount we care about.
my $light_care=40;
# Minimum light ammount.
my $screen_min=300;
# Maximum light ammount (resolution).
my $screen_max=1808;
# Minimum light ammount when AC is connected.
my $screen_min_ac=700;
# Brightness when laptop is on battery and in complete darkness.
my $screen_min_ac_dark=80;
# Steps for gradual fade.
my $screen_step=50;
# Delay between steps in the fade.
my $screen_fade_wait=100000; # 1000 microseconds = 1 milisecond.
# Minimum difference to change the brightness.
my $screen_min_diff=50;
# Path for screen backglight.
my $screen_script="/sys/class/backlight/intel_backlight/brightness";


# Settings for keyboard backlight.
# Steps for gradual fade.
my $keyb_step=4;
# Delay between steps in the fade.
my $keyb_fade_wait=80000;
# Bottom range of light ammount we care about.
my $keyb_light_care=20;
# Minimum light ammount.
my $keyb_min=0;
# Maximum keyboard brightness on battery.
my $keyb_max_bat=2;
# Maximum light ammount.
my $keyb_max=180; #actual max = 255.
# Minimum difference to change the brightness.
my $keyb_min_diff=20;
# Path for keyboard backglight.
my $keyb_script="/sys/class/leds/smc::kbd_backlight/brightness";


########################### Config ends here ###################################
my $keyb_now;
my $screen_now;
my $lightval=0; #max 255
my $locked=0;

sub keyb_now {
    $keyb_now=trim(`cat '/sys/class/leds/smc::kbd_backlight/brightness'`);
    debug_msg( $keyb_now."<-- keyb now\n" );
}

sub screen_now {
    $screen_now=trim(`cat '/sys/class/backlight/intel_backlight/brightness'`);
    debug_msg( $screen_now."<-- screen now\n" );
}

sub screen_gradually {
    my ($from, $to)=@_;
    
    return if $from == $to;
    my $action=0;
    $action=1 if $from>$to;

    my $difference=$from-$to;
    $difference=$difference * -1 if $difference <0;
    
    my $steps=ceil($difference/$screen_step);
    
    return if $difference < $screen_min_diff;
    
    debug_msg( "Screen from: $from; to: $to; diff: $difference; steps: $steps\n" );
    
    my $end;
    for(my $i=1; $i<=$steps; $i++){

            $end=$from+($screen_step*$i) if $action == 0;
            $end=$from-($screen_step*$i) if $action == 1;
            $end=$to if $i == $steps;

            #system @screen_script, ($end);
            system "echo $end > '$screen_script'";
            usleep($screen_fade_wait);

    }

}

sub keyb_gradually {
    my ($from, $to)=@_;
    
    return if $from == $to;
    my $action=0;
    $action=1 if $from>$to;

    my $difference=$from-$to;
    $difference=$difference * -1 if $difference <0;
    
    my $steps=ceil($difference/$keyb_step);
    
    return if $difference < $keyb_min_diff;
    
    debug_msg( "Keyb from: $from; to: $to; diff: $difference; steps: $steps\n" );
    
    my $end;
    for(my $i=1; $i<=$steps; $i++){

            $end=$from+($keyb_step*$i) if $action == 0;
            $end=$from-($keyb_step*$i) if $action == 1;
            $end=$to if $i == $steps;

            #system @keyb_script, ($end);
            system "echo $end > '$keyb_script'";
            usleep($keyb_fade_wait);
    }

}

sub worker {

    # Go home if lid is closed
    my $lid=system "grep closed '/proc/acpi/button/lid/LID0/state' > /dev/null 2>&1";
    return if $lid==0;

    # Go home if user has locked it
    my $lock=system "grep locked '$applock_file' > /dev/null 2>&1";
    
    if(-f $applock_file and $lock==0){
        
        if($locked == 0){
            system 'notify-send -i screensaver "Lighter locked" "Found lock file, not changing keyboard and screen backlight automatically."';
            $locked=1;
        }
        
        return;
    }else{
        if($locked==1){
            system 'notify-send -i screensaver "Lighter unlocked" "Lighter was unlocked, changing keyboard and screen backlight automatically."';
            $locked=0;
        }
    }

    

    # Check if the power adapter is connected
    my $ac=system "grep 1 '/sys/class/power_supply/ADP1/online' > /dev/null 2>&1";

    $lightval=trim(`cat '$sensor'`);
    $lightval =~ s/\((\d*),\d*\)/$1/;
    debug_msg( "Light value: $lightval\n" );

    &keyb_now();
    &screen_now();

    if($lightval > $keyb_light_care){
        debug_msg( "It is bright enough, turning off the keyboard backlight.\n" );
        &keyb_gradually($keyb_now, $keyb_min);

    }
    
    if($lightval < $keyb_light_care){
        debug_msg( "It is dark enough, turning on the keyboard backlight.\n" );
        
        my $klval=ceil($keyb_max/($lightval+1));
        $klval=$keyb_max_bat if $ac>0;
        &keyb_gradually($keyb_now, $klval );
    }

    if($lightval >= $light_care){
        &screen_gradually($screen_now, $screen_max);
    }
    
    if($lightval < $light_care){
        #ceil($light_max/100)*
        
        my $min=$screen_min;
        $min=$screen_min_ac;
        
        my $screenval= $min + floor ( ($screen_max-$min) * ($lightval / $light_care) );
        $screenval=$screen_min_ac_dark if $ac>0 and $lightval<=1;

        &screen_gradually( $screen_now, $screenval );
    }

}

sub debug_msg {
    print shift if $debug==1;
}

sub trim {
    #my $self=shift;
    my $string = shift;
    return if not $string;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $check_interval,
    first_interval => 0,
    on_tick => sub { &worker(@_) },
);
$timer->start;
$loop->add($timer);

$loop->run;

1;
