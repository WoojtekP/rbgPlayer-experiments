#!/usr/bin/env python3
# by aCat
# v0.7d

# todo
'''
teraz jest bez log_ na początku, a na końcu zamiast .txt jest .log, tak będzie trochę krócej;
po nazwie gry jest też podany limit czasowy albo symulacyjno-stanowy, warto więc po nim posortować;
przykład: breakthrough-s1000-mcts_orthodox_vs_semisplit_mcts_semisplit_simulator.log


'''

import os, re, sys, math
from scipy.stats import sem, t
from scipy import mean

VERBOSE = True

# logfile   names: log_[game]-[player1]_vs_[player2].txt
#                  [game]-[limits]-[player1]_vs_[player2].log
# logfile content: [time] [len] [legals] [scorePlayer1] [scorePlayer2] [[optional:timeout]]

class GameResults:
  def __init__(self, player1, player2, game):
    self.player1,self.player2,self.game,self.plays,self.score1,self.score2 = player1,player2,game,0,0,0
    self.draws,self.player1wins = 0,0
    self.scorelist1,self.scorelist2 = [],[]
    self.timeouts = {}
    #self.limits = limits
  def __str__(self):
        return str( (self.player1,self.player2,self.game,self.plays,self.score1,self.score2,self.timeouts) )

def arrangeFiles(logfiles):
  # returns {(player1, player2) -> {game -> [file] } }
  arrfiles = {}
  for f in logfiles:
    m = re.search('^(.+\-.+)\-(.+?)(\d*)([,\d]*)_vs_(.+?)(\d*)([,\d]*)\.log$', f)
    #print (m.group(0))
    #players = tuple(sorted( ( m.group(2)+m.group(4), m.group(5)+m.group(7) ) ) )
    players = tuple(sorted( ( m.group(2)+m.group(3)+m.group(4), m.group(5)+m.group(6)+m.group(7) ) ) )
    if players not in arrfiles:
      arrfiles[players] = {}
    if m.group(1) not in arrfiles[players]:
      arrfiles[players][m.group(1)] = []
    arrfiles[players][m.group(1)].append(f)
  return arrfiles

def calculateGameResults(players, game, logfiles, dir):
  gr = GameResults(players[0], players[1], game)
  for f in logfiles:
    m = re.search('^.+\-.+\-(.+?)(\d*)([,\d]*)_vs_.+\.log$', f)
    #print (m.group(0))
    #reverse = m.group(1)+m.group(3) != players[0]
    reverse = m.group(1)+m.group(2)+m.group(3) != players[0]
    with open(os.path.join(dir, f), 'r') as data:
      for entry in data:
        entry = entry.strip().split()
        #print(entry)
        gr.plays += 1
        if len(entry) > 5:
          tm = entry[5]
          if not entry[5] in gr.timeouts:
            gr.timeouts[entry[5]] = 0
          gr.timeouts[entry[5]] += 1
        #if len(gr.timeouts) > 0:
        #  gr.score1 = 0
        #  gr.score2 = 0
        #  gr.plays = -1
        #  break
        if reverse:
          gr.score1 += int(entry[4])
          gr.scorelist1.append(int(entry[4]))
          if int(entry[4]) > int(entry[3]): gr.player1wins += 1
          gr.score2 += int(entry[3])
          gr.scorelist2.append(int(entry[3]))
        else: 
          gr.score1 += int(entry[3])
          gr.scorelist1.append(int(entry[3]))
          if int(entry[3]) > int(entry[4]): gr.player1wins += 1
          gr.score2 += int(entry[4])
          gr.scorelist2.append(int(entry[4]))
        if entry[4] == entry[3]:
          #print (entry[4], entry[3], gr.draws)
          gr.draws += 1
  return gr

def clearInDirectory(dir):
  otherfiles = [f for f in os.listdir(dir) if not re.search('.log$', f) and not re.search('.sh$', f)]
  #print ('\n'.join(otherfiles))
  if VERBOSE: print('INFO: Found %d other files in directory %s.' % (len(otherfiles), dir) )
  for f in otherfiles: os.remove(os.path.join(dir, f))
  if VERBOSE: print('INFO: Removed.' )


def runInDirectory(dir):
  logfiles = [f for f in os.listdir(dir) if re.search('.log$', f) and not f.startswith('manager')]
  if VERBOSE: print('INFO: Found %d logfiles in directory %s.' % (len(logfiles), dir) )

  arrfiles = arrangeFiles(logfiles)
  if VERBOSE: print('INFO: Found %d pairs of players.' % len(arrfiles))


  for players, gamefiles in arrfiles.items():
    results = []
    outfile = '_RESULTS_%s_vs_%s.txt' % (players[0], players[1])
    for game, logfiles in gamefiles.items():
      results.append(calculateGameResults(players, game, logfiles, dir))
    out = []
    playsum = 0
    for gr in sorted(results, key=lambda r: (r.game.split('-')[0], float(re.sub('[a-zA-Z]', '',r.game.split('-')[1])))):
      #print ((gr.game.split('-')[0], int(re.sub('[a-zA-Z]', '',gr.game.split('-')[1]))))
      #out.append('{0:<22} {1:4} {2:6.2f} {3:6.2f}   // draws:{4:6.1f}%  Pinf:{5:3d} Pinf:{6:6.1f}%\n'.format(gr.game, gr.plays, gr.score1/gr.plays, gr.score2/gr.plays, 100*gr.draws/gr.plays, gr.player1inf, 100*gr.player2inf/gr.plays))
      #print (len(gr.scorelist1), gr.scorelist1)
      #print (len(gr.scorelist2), gr.scorelist2)
      if gr.plays < 1:
        continue
      avg1 = gr.score1/gr.plays
      var1 = sum([ (s-avg1)**2 for s in gr.scorelist1])/(gr.plays-1)
      std1 =  math.sqrt(var1)
      avg2 = gr.score2/gr.plays
      #std2 = math.sqrt(sum([ (s-avg2)**2 for s in gr.scorelist2])/(gr.plays-1))
      #print (std1, std2)
      playsum += gr.plays

      ternEXP = (gr.player1wins + gr.draws/2)/gr.plays
      #print (ternEXP, avg1) # OK, equal

      #ternVAR = (ternEXP)*(1-ternEXP)
      ternVAR = (gr.player1wins + gr.draws/4)/gr.plays - ternEXP*ternEXP


      #print (ternVAR, var1 - 100*(gr.draws/4)/gr.plays) # ???

      ternSTDERR = math.sqrt(ternVAR) / math.sqrt(gr.plays)

      #print (avg1, mean(gr.scorelist1) # OK, equal
      std_err1 =std1 / math.sqrt(gr.plays)
      #print (std_err1, sem(gr.scorelist1)) # OK, equal

      #print (std_err1, ternSTDERR) # ???

      std_err = sem(gr.scorelist1)
      h = std_err * t.ppf((1 + 0.95) / 2, gr.plays - 1)

      tern95CI = 100* ( 1.96 *(math.sqrt(ternVAR)) / math.sqrt(gr.plays - 1) )
      #print (h, tern95CI) # ???




      #out.append('{0:<42} {1:4} {2:6.1f} {3:6.1f}    {4:4.1f}  {5:6.1f}      {6}\n'.format(gr.game, gr.plays, avg1, avg2, std1, h, ",".join(("{}:{}x".format(*i) for i in gr.timeouts.items()))))
      out.append('{0:<42} {1:4} {2:6.1f} {3:6.1f}    {4:4.1f}  {5:6.1f}      {6}\n'.format(gr.game, gr.plays, avg1, avg2,100*math.sqrt(ternVAR), tern95CI, ",".join(("{}:{}x".format(*i) for i in gr.timeouts.items()))))
    
    # here global stats per limit
    perlimit = {} # limit -> [GameResult]
    for gr in results:
      limit = gr.game.split('-')[1]
      if not limit in perlimit:
        perlimit[limit] = []
      perlimit[limit].append(gr)

    out2 = []
    for limit in sorted(perlimit.keys()):
      grs = perlimit[limit]
      s1 = [gr.score1/gr.plays for gr in grs]
      s2 = [gr.score2/gr.plays for gr in grs]
      avg1 = sum(s1) / len(grs)
      avg2 = sum(s2) / len(grs)
      std1 = math.sqrt(sum([ (s-avg1)**2 for s in s1])/len(s1))
      out2.append('  {0:<8} {1:6.2f}      {2:6.2f}       {3:2.2f}\n'.format(limit, avg1, avg2, std1 ))



    with open(os.path.join(dir, outfile), 'w') as f:
      f.write('INFO: PLAYERS: %s VS %s:\n' %(players[0], players[1]) )
      f.write('game-test                                  n   scoreP1 scoreP2   sdev     95%CI    errors\n')
      f.writelines(out)
      f.write('\ntest        AvgScoreP1  AvgScoreP2  std      // summary: %d games, %d plays\n'  % (len(results), playsum) )
      f.writelines(out2)
    #print('INFO: %d results for players %s & %s saved into "%s":' %(len(results), players[0], players[1], outfile) )
    #print('INFO: DIR: %s \nINFO: PLAYERS: %s VS %s:' %(dir, players[0], players[1]) )
    print('INFO: PLAYERS: %s VS %s:' %(players[0], players[1]) )
    print('  game-test                                  n   scoreP1 scoreP2   sdev     95%CI    errors')
    for outline in out:
      print('  ' + outline,end='')
    print('test        AvgScoreP1  AvgScoreP2  std      // summary: %d games, %d plays' % (len(results), playsum))
    for outline in out2:
      print(outline,end='')

def getLogdirs(dir):
  dirlist = [dir]
  for r, d, f in os.walk(dir):
    for recdir in d:
      #if file.endswith(".txt") and file.startswith("log_"):
      #print (recdir)
      #print(os.path.join(r, recdir))
      dirlist.append( os.path.join(r, recdir) )
      #logfiles.append( os.path.join(r, file)  )
  #return [f for f in os.listdir(dir) if re.search('^log_.+\.txt$', f)]
  #print (logfiles)
  return dirlist

if __name__ == '__main__':
  if len(sys.argv) < 2:
    print('ERROR: The first argument should be directory containing log files.')
    sys.exit(1)

  dir = sys.argv[1]

  dirlist = getLogdirs(dir)

  for d in dirlist:
    #clearInDirectory(d)
    runInDirectory(d)

if VERBOSE: print('INFO: done.')