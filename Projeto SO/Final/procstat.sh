#!/bin/bash

#Validação de s
valid_number_regex='^[0-9]+$'
if ! [[ ${@: -1} =~ $valid_number_regex ]] ; then
   echo "Parâmetro 's' inválido."; exit 1
fi

# O h tira o cabeçalho, o -N -u root tira os processos da root, o "u" mostra o nome do utilizador
PIDS=$(ps uhfax | awk '{print $2}')

#Arrays cujos índices correspondem aos PIDs
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

pids_to_delete=()

max_comm_length=20
#Para formatação, alguns processos têm COMM muito compridos
#Número mínimo de espaços: 20

PIDS_tmp=()
for i in $PIDS; do
	if [ -f "/proc/$i/status" ] && [ -f "/proc/$i/io" ]; then
		input_status="/proc/$i/status"
		vmSize[$i]=$(cat $input_status | grep ^VmSize: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)
		vmRSS[$i]=$(cat $input_status | grep ^VmRSS: | cut -d':' -f2 | cut -f2 | cut -d'k' -f1 | xargs)

		if ! [ -z "${vmSize[$i]}" ] && ! [ -z "${vmRSS[$i]}" ]; then
			input_io="/proc/$i/io"
			input_date="/proc/$i"
			users[$i]=$(ps uh $i | awk '{print $1}')
			comm[$i]=$(ps -h -q $i -o comm)
			dates[$i]=$(ls -ld $input_date | awk '{print $6 ";" $7 ";" $8}' )
			dates_epoch[$i]=$(date -r $input_date "+%s")
			rI[$i]=$(cat $input_io | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
			wI[$i]=$(cat $input_io | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)

			PIDS_tmp[$i]=$i

			length=$(expr length "${comm[$i]}")

			if (( $length > $max_comm_length )); then
				max_comm_length=$(( $length + "1" ));	#+1 para não ficar colado ao USER
			fi
		fi
	fi
done

PIDS="${PIDS_tmp[@]}"
sleep ${@: -1} #último argumento - parâmetro s

for i in $PIDS; do
	input_io="/proc/$i/io"

	rF[$i]=$(cat $input_io | grep ^rchar: | cut -d':' -f2 | cut -f2 | xargs)
	rC_dif=$((${rF[$i]} - ${rI[$i]}))
	if [[ "$rC_dif" -eq 0 ]]; then						#não dividir por 0
		rC[$i]=0
	elif ! [[ "${@: -1}" -eq 0 ]]; then
		rC[$i]=$(bc -l <<< "scale=1; $rC_dif/${@: -1}")	#divisão não inteira
	else
		rC[$i]=$rC_dif	#mostra os bytes de leitura no tempo de execução
	fi
	
	wF[$i]=$(cat $input_io | grep ^wchar: | cut -d':' -f2 | cut -f2 | xargs)
	wC_dif=$((${wF[$i]} - ${wI[$i]}))
	if [[ "$wC_dif" -eq 0 ]]; then
		wC[$i]=0
	elif ! [[ "${@: -1}" -eq 0 ]]; then
		wC[$i]=$(bc -l <<< "scale=1; $wC_dif/${@: -1}")
	else
		wC[$i]=$wC_dif	#mostra os bytes de escrita no tempo de execução
	fi

	echo "${comm[$i]};${users[$i]};$i;${vmSize[$i]};${vmRSS[$i]};${rI[$i]};${wI[$i]};${rC[$i]};${wC[$i]};${dates[$i]};${dates_epoch[$i]}" >> data.txt
done

if [[ -f "./data_sorted.txt" ]]; then
	rm "./data_sorted.txt"
fi

sort data.txt >> data_sorted.txt
rm data.txt

input="./data_sorted.txt"

while getopts ":u:c:s:e:p:mtdwir" opt; do
	case $opt in
		u)
			invalid=true
			while IFS= read -r line; do
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
			while IFS= read -r line; do
				date_epoch=$(echo $line | cut -d';' -f13 | xargs)
				optarg_epoch=$(date -d "${OPTARG}" +"%s")
				if (( date_epoch >= optarg_epoch )); then
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
			while IFS= read -r line; do
				date_epoch=$(echo $line | cut -d';' -f13 | xargs)
				optarg_epoch=$(date -d "${OPTARG}" +"%s")
				if (( date_epoch <= optarg_epoch )); then
					echo $line >> tmp.txt
				fi
	    	done < "$input"
			mv tmp.txt data_sorted.txt;;
		p)(head -$OPTARG data_sorted.txt) > tmp.txt; mv tmp.txt data_sorted.txt;;
		m)(sort data_sorted.txt -r -k4 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		t)(sort data_sorted.txt -r -k5 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		d)(sort data_sorted.txt -r -k8 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;
		w)(sort data_sorted.txt -r -k9 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;	#sort por
		i)(sort data_sorted.txt -r -k3 -nt ';') > tmp.txt; mv tmp.txt data_sorted.txt;;	#sort por PID (Para debugging)
		r)(tac data_sorted.txt) > tmp.txt; mv tmp.txt data_sorted.txt;;					#cat, mas começa pela última linha
		\?) exit 1;;
	esac
done

printf "%-${max_comm_length}s%-15s%+15s%+15s%+15s%+15s%+15s%+15s%+15s%+15s\n" "COMM" "USER" "PID" "MEM" "RSS" "READB" "WRITEB" "RATER" "RATEW" "DATE"
while IFS= read -r line; do
	printf "%-${max_comm_length}s%-15s%+15s%+15s%+15s%+15s%+15s%15.1f%15.1f%+6s%3s%6s\n" "$(echo $line | cut -d';' -f1 | xargs)" "$(echo $line | cut -d';' -f2 | xargs)" "$(echo $line | cut -d';' -f3 | xargs)" "$(echo $line | cut -d';' -f4 | xargs)" "$(echo $line | cut -d';' -f5 | xargs)" "$(echo $line | cut -d';' -f6 | xargs)" "$(echo $line | cut -d';' -f7 | xargs)" "$(echo $line | cut -d';' -f8 | xargs)" "$(echo $line | cut -d';' -f9 | xargs)" "$(echo $line | cut -d';' -f10 | xargs)" "$(echo $line | cut -d';' -f11 | xargs)" "$(echo $line | cut -d';' -f12 | xargs)"
done < "$input"

rm ./data_sorted.txt;
#Duvidas para o sor:
	#São estes processos todos, ou só alguns em especifico #tirar os que não tivessem stats que queremos ver
	#Rchar e Wchar, como fazer sleep em apenas 1 ciclo for?	#não
	#Nós precisamos de fazer sudo para dar alguns processos, é suposto? #pra ver root
	#Pode ocorrer o caso de se meter vários sorts ao mesmo tempo? #idk? enviar mail? probs not
#Para fazer as opções(tipo -c), usar getops, e depois um case, ver foto do messenger
#No final, eliminar todos os files criados