# Arjun: Thermal script to print out the thermal zone temperature sysfs entries in a loop
# and store it in csv data format to plot with excel
# Default Values: 100 iterations with 5 Second delay. Data is stored in thermal_data.csv
COUNT=100
DELAY=5
OUTFILE=thermal_data.csv

touch $OUTFILE

function usage
{
    echo "usage: thermal [[[-c count ] [ -d delay] [-f output csv file]] | [-h help]]"
}

# Get arguments
while [ "$1" != "" ]; do
    case $1 in
        -c | --count )          shift
                                COUNT=$1
                                ;;
		-d | --delay )			shift
								DELAY=$1
								;;
        -f | --filename )		OUTFILE=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#Sysfs paths
THERMALSYSFS="/sys/class/thermal"
CPUSYSFS="/sys/devices/system/cpu"
GTSYSFS="/sys/kernel/debug/dri/0/"
RAPLSYSFS="/sys/class/powercap/intel-rapl/intel-rapl:0"

# Count number of thermal zone then subtract 1 because 
# zone numbering starts from 0: thermal_zone0, thermal_zone1 etc
NUMTHERMAL=$(find $THERMALSYSFS -type l | grep -i thermal_zone | wc -l)
NUMTHERMAL=$((NUMTHERMAL - 1))

# Count number of cpu cores and then subtract 1 because 
# cpu numbering starts from 0: cpu0, cpu1 etc
NUMCPU=$(find $CPUSYSFS/cpu*/cpufreq -type l | grep -i cpu | wc -l)
NUMCPU=$((NUMCPU - 1))

#echo $NUMCPU

# Generate Header with thermal zone type because this may change for each
#TODO: Remove CPU Freq and GPU Freq hack  
HEADER=$(cat $THERMALSYSFS/thermal_zone*/type | tr '\n' ',')
HEADER="Timestamp,$HEADER"
HEADER+="CPU0,CPU0THROTTLE,CPU1,CPU1THROTTLE,CPU2,CPU2THROTTLE,CPU3,CPU3THROTTLE,GT,RAPL0"
echo $HEADER | tee -a $OUTFILE

# Outer loop to loop therough number of iterations
for i in $(seq 1 $COUNT)
do	
	# Get time in Hour:Minute:Seconds
    TIMESTAMP=$(date +%T)
	
	OUT="$TIMESTAMP"	

	# Inner loop to loop through the thermal_zones defined by the thermal driver
	for j in $(seq 0 $NUMTHERMAL)
	do
		THERMALZONE=$(cat $THERMALSYSFS/thermal_zone$j/temp)
		OUT="$OUT,$THERMALZONE"
			
		# if [ "$j" == "$NUMTHERMAL" ]
		# then
			# echo $OUT | tee -a $OUTFILE
		# fi
	done

	# Inner loop to loop through the cpu cores
	for j in $(seq 0 $NUMCPU)
	do
		CPU=$(cat $CPUSYSFS/cpu$j/cpufreq/cpuinfo_cur_freq)
		CPUTHROTTLE=$(cat $CPUSYSFS/cpu$j/thermal_throttle/package_throttle_count)
		OUT="$OUT,$CPU,$CPUTHROTTLE"
	done
	
	# Current GPU Frequency
	GPU=$(cat $GTSYSFS/i915_frequency_info | grep -i "Current freq" | grep -o '[0-9]*')
	OUT=$OUT,$GPU
	
	# For RAPL power get 1st measurement with timestamp
	P1=$(cat $RAPLSYSFS/energy_uj)
	T1=$(date +%s)
	
	sleep $DELAY
	
	# For RAPL package power get 2nd measurement with timestamp
	P2=$(cat $RAPLSYSFS/energy_uj)
	T2=$(date +%s)
	
	#Convert to mw
	PWR=$(bc <<< "scale=2;($P2-$P1)/($T2-$T1)/1000000")
	#echo $PWR
	
	OUT=$OUT,$PWR
	
	echo $OUT | tee -a $OUTFILE
done

