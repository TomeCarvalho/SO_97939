#!/bin/bash

valid_number_regex='^[0-9]+$'
if ! [[ ${@: -1} =~ $valid_number_regex ]] ; then
   echo "Parâmetro 's' inválido."; exit 1
fi

# O h tira o cabeçalho, o -N -u root tira os processos da root, o "u" mostra o nome do utilizador
PIDS=$(ps uhfax | awk '{print $2}')

users=()		#USER
comm=()			#COMM
vmSize=()		#MEM
vmRSS=()		#RSS
rI=()			#READB
wI=()			#WRITEB
rF=()			#para cálculo de RATER
wF=()			#para cálculo de RATEW
rC=()			#RATER
wC=()			#RATEW
dates=()		#DATE
dates_epoch=()	#para comparação de datas (-s, -e)

for i in $PIDS
do
	inputstatus="/proc/$i/status"
	inputio="/proc/$i/io"
	inputdate="/proc/$i"
	users[$i]=$(ps uh $i | awk '{print $1}')
	comm[$i]=$(ps -h -q $i -o comm)
	dates[$i]=$(ls -ld $inputdate | awk '{print $6 ";" $7 ";" $8}' )
	dates_epoch[$i]=$(date -r $inputdate "+%s")
	vmSize[$i]=$(cat $inputstatus | grep ^VmSize: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)
	vmRSS[$i]=$(cat $inputstatus | grep ^VmRSS: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)
	rI[$i]=$(cat $inputio | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
	wI[$i]=$(cat $inputio | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)
done

sleep ${@: -1} #último argumento

for i in $PIDS
do
	inputio="/proc/$i/io"
	rF[$i]=$(cat $inputio | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
	rC[$i]=$((${rF[$i]} - ${rI[$i]}))
	wF[$i]=$(cat $inputio | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)
	wC[$i]=$((${wF[$i]} - ${wI[$i]}))

	echo "${comm[$i]};${users[$i]};$i;${vmSize[$i]};${vmRSS[$i]};${rI[$i]};${wI[$i]};${rC[$i]};${wC[$i]};${dates[$i]};${dates_epoch[$i]}" >> data.txt #test.txt
done

if [[ -f "./data_sorted.txt" ]]
then
	rm "./data_sorted.txt"
fi

sort data.txt >> data_sorted.txt
rm data.txt

input="./data_sorted.txt"

while getopts ":u:c:s:e:p:mtdwr" opt; do
	case $opt in
		u)
			invalid=true
			while IFS= read -r line
			do
				usr=$(echo $line | cut -d ';' -f2 | xargs)
				if [[ $usr == $OPTARG ]]; then
					echo $line >> tmp.txt
					invalid=false
				fi
			done < "$input"
			if $invalid; then
				echo "Não há processos a serem corridos pelo utilizador $OPTARG."
				exit 1
			fi
			mv tmp.txt data_sorted.txt;;
		c)
			(cat $input | grep "^$OPTARG") > tmp.txt;
			mv tmp.txt data_sorted.txt;;
		s)
			date -d "${OPTARG}" > /dev/null
			if [ $? -ne "0" ]; then
				echo "Data inválida."
				exit 1
			fi
			while IFS= read -r line
			do
				date_epoch=$(echo $line | cut -d';' -f13 | xargs)
				optarg_epoch=$(date -d "${OPTARG}" +"%s")
				if (( date_epoch >= optarg_epoch ))
				then
					echo $line >> tmp.txt
				fi
	    	done < "$input"
			mv tmp.txt data_sorted.txt;;
		e)
			date -d "${OPTARG}" > /dev/null
			if [ $? -ne "0" ]; then
				echo "Data inválida."
				exit 1
			fi
			while IFS= read -r line
			do
				date_epoch=$(echo $line | cut -d';' -f13 | xargs)
				optarg_epoch=$(date -d "${OPTARG}" +"%s")
				if (( date_epoch <= optarg_epoch ))
				then
					echo $line >> tmp.txt
				fi
	    	done < "$input"
			mv tmp.txt data_sorted.txt;;
		p)(head -$OPTARG data_sorted.txt) > tmp.txt; mv tmp.txt data_sorted.txt;;
		m)(sort data_sorted.txt -r -k4 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		t)(sort data_sorted.txt -r -k5 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		d)(sort data_sorted.txt -r -k8 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		w)(sort data_sorted.txt -r -k9 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		r)(tac data_sorted.txt) > tmp.txt; mv tmp.txt data_sorted.txt;;
		\?) exit 1;;
	esac
done

printf "%-25s%-15s%+15s%+15s%+15s%+15s%+15s%+15s%+15s%+15s\n" "COMM" "USER" "PID" "MEM" "RSS" "READB" "WRITEB" "RATER" "RATEW" "DATE"
while IFS= read -r line
do
	printf "%-25s%-15s%+15s%+15s%+15s%+15s%+15s%+15s%+15s%+6s%3s%6s\n" "$(echo $line | cut -d';' -f1 | xargs)" "$(echo $line | cut -d';' -f2 | xargs)" "$(echo $line | cut -d';' -f3 | xargs)" "$(echo $line | cut -d';' -f4 | xargs)" "$(echo $line | cut -d';' -f5 | xargs)" "$(echo $line | cut -d';' -f6 | xargs)" "$(echo $line | cut -d';' -f7 | xargs)" "$(echo $line | cut -d';' -f8 | xargs)" "$(echo $line | cut -d';' -f9 | xargs)" "$(echo $line | cut -d';' -f10 | xargs)" "$(echo $line | cut -d';' -f11 | xargs)" "$(echo $line | cut -d';' -f12 | xargs)"
done < "$input"

rm ./data_sorted.txt;
#Duvidas para o sor:
	#São estes processos todos, ou só alguns em especifico
	#Rchar e Wchar, como fazer sleep em apenas 1 ciclo for?
	#Nós precisamos de fazer sudo para dar alguns processos, é suposto?
	#Pode ocorrer o caso de se meter vários sorts ao mesmo tempo?
#Para fazer as opções(tipo -c), usar getops, e depois um case, ver foto do messenger
#No final, eliminar todos os files criados
	
#Bug: com s = 0 não está a dar 0 para todos os RATER e RATEW