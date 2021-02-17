#!/bin/bash
# v. 17.02.2021
#                 $1           $2                                                $3         $4     $5     $6
#./run_matches.sh breakthrough mcts_orthodox_orthodox mcts_semisplitNodal_semisplit $boundtype $bound $plays

#ports="7780"
#ports="7780 7781 7782 7783"
ports="7780 7781 7782 7783 7784 7785"
logs="logs"

######## Benchmark ########
# mcts_orthodox_orthodox
declare -A simLimitsO
simLimitsO=(\
  ["amazons"]=2222.6\
  ["breakthrough"]=29502.1\
  ["breakthru"]=30.5\
  ["chess"]=667.8\
  ["chess_kingCapture"]=4794.0\
  ["englishDraughts"]=417948.0\
  ["foxAndHounds"]=167967.5\
  ["go_constsum"]=154.0\
  ["gomoku_standard"]=5877.6\
  ["hex"]=10037.8\
  ["knightthrough"]=46276.9\
  ["pentago"]=9095.4\
  ["reversi"]=16327.5\
  ["skirmish"]=5797.3\
  ["theMillGame"]=26130.9\
)
declare -A stateLimitsO
stateLimitsO=(\
  ["amazons"]=158760.4\
  ["breakthrough"]=1885488.2\
  ["breakthru"]=6391.9\
  ["chess"]=211225.3\
  ["chess_kingCapture"]=562180.6\
  ["englishDraughts"]=2886068.2\
  ["foxAndHounds"]=7936776.2\
  ["go_constsum"]=89900.6\
  ["gomoku_standard"]=660701.0\
  ["hex"]=1079052.0\
  ["knightthrough"]=1500851.1\
  ["pentago"]=264438.2\
  ["reversi"]=986354.8\
  ["skirmish"]=579728.1\
  ["theMillGame"]=1630672.6\
)
# mcts_orthodox_orthodox_mast_rave
declare -A stateLimitsOMR
stateLimitsOMR=(\
  ["amazons"]=48347.2\
  ["breakthrough"]=1174971.7\
  ["breakthru"]=2927.4\
  ["chess"]=168819.9\
  ["chess_kingCapture"]=250213.9\
  ["englishDraughts"]=1930340.9\
  ["foxAndHounds"]=3508157.6\
  ["go_constsum"]=78804.6\
  ["gomoku_standard"]=258172.0\
  ["hex"]=494426.0\
  ["knightthrough"]=827723.8\
  ["pentago"]=134244.4\
  ["reversi"]=836441.0\
  ["skirmish"]=251108.8\
  ["theMillGame"]=1183972.4\
)


function wait_and_terminate {
  jobs
  wait < <(jobs -p)
  killall start_server
  killall python3
  sleep 0.1
  killall orthodox_orthodox 2> /dev/null
  killall orthodox_orthodox_mast 2> /dev/null
  killall orthodox_orthodox_mastsplit 2> /dev/null
  killall orthodox_orthodox_rave 2> /dev/null
  killall orthodox_orthodox_mast_rave 2> /dev/null
  killall orthodox_semisplit 2> /dev/null
  killall orthodox_semisplit_mastsplit 2> /dev/null
  killall semisplit_semisplit 2> /dev/null
  killall semisplit_semisplit_mast 2> /dev/null
  killall semisplit_semisplit_mastsplit 2> /dev/null
  killall semisplit_semisplit_mastcontext 2> /dev/null
  killall semisplit_semisplit_rave 2> /dev/null
  killall semisplit_semisplit_ravecontext 2> /dev/null
  killall semisplit_semisplit_ravemix 2> /dev/null
  killall semisplit_semisplit_mast_rave 2> /dev/null
  killall semisplit_semisplit_mastcontext_ravecontext 2> /dev/null
  killall semisplit_orthodox 2> /dev/null
  killall semisplit_orthodox_mastsplit 2> /dev/null
  killall orthodox_orthodox_tgrave 2> /dev/null
  killall orthodox_orthodox_mast_tgrave 2> /dev/null
  killall orthodox_semisplit_mastsplit_tgrave 2> /dev/null
  killall semisplit_semisplit_mastmix 2> /dev/null
  killall semisplit_semisplit_tgrave 2> /dev/null
  killall semisplit_semisplit_mast_tgrave 2> /dev/null
  killall semisplit_semisplit_mastsplit_tgrave 2> /dev/null
  killall semisplit_semisplit_mastsplit_ravecontext 2> /dev/null
  killall semisplit_semisplit_mastmix_ravecontext 2> /dev/null
  killall rollup_semisplit 2> /dev/null
  killall rollup_semisplit_mastcontext 2> /dev/null
  killall rollup_semisplit_mastmix 2> /dev/null
  killall rollup_orthodox 2> /dev/null
  sleep 0.1
  cd rbgPlayer
  make distclean > /dev/null
  cd ..
}
function wait_for_manager_2 {
  for i in {1..250}; do
  sleep 0.02
  lastline=`tail -n 1 $1`
  if [ "$lastline" == "Waiting for clients...(2 more needed)" ] ; then
    #echo "Manager ready after $i tries"
    sleep 0.02
    return
  fi
  done
  echo "Manager was not ready!"
  exit 2
}
function wait_for_manager_1 {
  for i in {1..250}; do
  sleep 0.02
  lastline=`tail -n 1 $1`
  if [ "$lastline" == "Waiting for clients...(1 more needed)" ] ; then
    #echo "Client 0 connected after $i tries"
    sleep 0.02
    return
  fi
  done
  echo "Client 0 did not connect!"
  exit 2
}
#trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

wait_and_terminate

game=$1
gamename=$(basename ${game})
player1=$2
player2=$3
boundtype=$4
bound=$5
plays=$6
inittime=600000
if [ $boundtype == "t" ]; then
  movetime=$(bc <<< "${bound}+100")
  matchid=${gamename}-t${bound}
  boundtype=""
  bound=""
elif [ $boundtype == "m" ]; then
  matchid=${gamename}-m${bound}
  movetime=$(bc <<< "${inittime}/2")
  boundtype="--simulations-limit"
elif [ $boundtype == "s" ]; then
  matchid=${gamename}-s${bound}
  movetime=$(bc <<< "${inittime}/2")
  boundtype="--states-limit"
else
matchid=${gamename}-${boundtype}${bound}
basevariant=${gamename%"_exp"}
basevariant=${basevariant%"_exp1"}
basevariant=${basevariant%"_exp2"}
basevariant=${basevariant%"_exp3"}
basevariant=${basevariant%"_exp4"}
movetime=$(bc <<< "$inittime/2")
if [ $boundtype == "fmO" ]; then
  if [ -z ${simLimitsO[$basevariant]} ]; then
    echo "Game ${gamename} is not in simLimitsO!"
    exit 1
  fi
  boundtype="--simulations-limit"  
  bound=$(bc <<< "(( ${simLimitsO[$basevariant]} * $bound + 500) / 1000.0 )/1")
elif [ $boundtype == "fsO" ]; then
  if [ -z ${stateLimitsO[$basevariant]} ]; then
    echo "Game ${gamename} is not in stateLimitsO!"
    exit 1
  fi
  boundtype="--states-limit"
  bound=$(bc <<< "(( ${stateLimitsO[$basevariant]} * $bound + 500) / 1000.0 )/1")
elif [ $boundtype == "fsOMR" ]; then
  if [ -z ${stateLimitsOMR[$basevariant]} ]; then
    echo "Game ${gamename} is not in stateLimitsOMR!"
    exit 1
  fi
  boundtype="--states-limit"
  bound=$(bc <<< "(( ${stateLimitsOMR[$basevariant]} * $bound + 500) / 1000.0 )/1")
else
  echo "Wrong bound type: ${boundtype}"
  exit 1
fi
fi

function runAgent {
  if [ $1 == 'random' ]; then
    python3 rbggamemanager/build/start_random_python_client.py 127.0.0.1 $port > ${logs}/agent_$1-${halfmatchid}-${port}.txt 2>&1 &
    #rbggamemanager/build/start_random_client 127.0.0.1 ${port} > ${logs}/agent_$1-${halfmatchid}-${port}.txt 2>&1 &
  else
    python3 rbgPlayer/play.py 127.0.0.1 ${port} agents/$1.json --release ${boundtype} ${bound} > /dev/null &
    #python3 rbgPlayer/play.py 127.0.0.1 ${port} agents/$1.json --release --stats ${boundtype} ${bound} > ${logs}/player_$1-${halfmatchid}-${port}.txt 2>&1 &
  fi
}

function halfmatch {
  halfmatchid=${matchid}-$1_vs_$2
  if test -f "${logs}/${halfmatchid}.log"; then
    echo "******** Skipped ${halfmatchid} -- log already exists"
    return
  fi
  echo "******** Running ${halfmatchid} (plays ${plays} ports ${ports})"
  date
  for port in ${ports}; do
    rbggamemanager/build/start_server rbgGames/games/${game}.rbg ${port} --limit ${plays} --time_for_player_preparation ${inittime} --deadline ${movetime} \
      --log_results ${logs}/_part${port}-${halfmatchid}.txt > ${logs}/_part${port}-manager_${halfmatchid}.txt 2>&1 &
    wait_for_manager_2 ${logs}/_part${port}-manager_${halfmatchid}.txt
    runAgent $1
    wait_for_manager_1 ${logs}/_part${port}-manager_${halfmatchid}.txt
    runAgent $2
  done
  wait_and_terminate
  error=0
  for port in ${ports}; do
    len=$(wc -l < ${logs}/_part${port}-${halfmatchid}.txt)
    if [ ${len} -ne ${plays} ]; then
      echo "Error: incomplete part ${port} with ${len} plays"
      error=1
    fi
  done
  if [ $error == 1 ]; then
    echo "******** Skipping due to error"
    return
  fi
  for port in ${ports}; do
    cat ${logs}/_part${port}-${halfmatchid}.txt >> ${logs}/${halfmatchid}.log
    rm ${logs}/_part${port}-${halfmatchid}.txt
    cat ${logs}/_part${port}-manager_${halfmatchid}.txt >> ${logs}/manager_${halfmatchid}.txt
    rm ${logs}/_part${port}-manager_${halfmatchid}.txt
  done
}

halfmatch $player1 $player2
halfmatch $player2 $player1
