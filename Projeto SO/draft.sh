#!/bin/bash

function filterbyname() {	
	while IFS= read -r line
	do
		echo "$line"
	done < "$2"

}

PIDS=$(ps uh -N -u root | awk '{print $2}') # O h tira o cabeçalho, o -N -u root tira os processos da root, o "u" mostra o nome do utilizador
users=()
comm=()
vmSize=()
vmRSS=()
rI=()
wI=()
rF=()
wF=()
rC=()
wC=()
dates=()

for i in $PIDS
do
	inputcomm="/proc/$i/comm"
	inputstatus="/proc/$i/status"
	inputio="/proc/$i/io"
	inputdate="/proc/$i"
	users[$i]=$(ps uh $i | awk '{print $1}')
	comm[$i]=$(cat $inputcomm)
	dates[$i]=$(ls -ld $inputdate | awk '{print $6 ";" $7 ";" $8}' )
	vmSize[$i]=$(cat $inputstatus | grep ^VmSize: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)
	vmRSS[$i]=$(cat $inputstatus | grep ^VmRSS: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)
	rI[$i]=$(cat $inputio | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
	wI[$i]=$(cat $inputio | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)
done

sleep 1 #Não será este, será o ultimo argumento

for i in $PIDS
do
	inputio="/proc/$i/io"
	rF[$i]=$(cat $inputio | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
	rC[$i]=$((${rF[$i]} - ${rI[$i]}))
	wF[$i]=$(cat $inputio | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)
	wC[$i]=$((${wF[$i]} - ${wI[$i]}))

	echo "${comm[$i]}|${users[$i]}|$i|${vmSize[$i]}|${vmRSS[$i]}|${rI[$i]}|${wI[$i]}|${rC[$i]}|${wC[$i]}|${dates[$i]}" >> data.txt #test.txt
done

if [[ -f "./data_sorted.txt" ]]
then
	rm "./data_sorted.txt"
fi

sort data.txt >> data_sorted.txt
rm data.txt

input="./data_sorted.txt"

while getopts ":c:s:e:u:p:mtdwr" opt; do
	case $opt in
		c)
			(cat $input | grep "^$OPTARG") > tmp.txt;
		  	rm data_sorted.txt;
		  	cp tmp.txt data_sorted.txt;
		  	rm tmp.txt;;
		s)
			while IFS= read -r line
			do
				
				datafile > $OPTARG
	    	done < "$input";;
		e);;
		u)(awk -F';' '$2==$OPTARG' data_sorted.txt) > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		p)(-head $OPTARG data_sorted.txt) > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		m)(sort data_sorted.txt -k4 -n -t '|') > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		t)(sort data_sorted.txt -k5 -t ';') > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		d)(sort data_sorted.txt -k8 -t ';') > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		w)(sort data_sorted.txt -k9 -t ';') > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		r)(sort data_sorted.txt -r -t ';') > tmp.txt; rm data_sorted.txt; cp tmp.txt data_sorted.txt; rm tmp.txt;;
		\?) exit 1;;
	esac
done
2
#Duvidas para o sor:
	#São estes processos todos, ou só alguns em especifico
	#Rchar e Wchar, como fazer sleep em apenas 1 ciclo for?
	#Nós precisamos de fazer sudo para dar alguns processos, é suposto?
	#Pode ocorrer o caso de se meter vários sorts ao mesmo tempo?

#Para fazer as opções(tipo -c), usar getops, e depois um case, ver foto do messenger
#No final, eliminar todos os files criados
	
