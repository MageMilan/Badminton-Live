<script setup>
import { ref, onMounted } from 'vue'
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://your-supabase-url.supabase.co'
const supabaseAnonKey = 'your-anon-public-key'

const useSupabase = supabaseUrl !== 'https://your-supabase-url.supabase.co' && supabaseAnonKey !== 'your-anon-public-key'
const supabase = useSupabase ? createClient(supabaseUrl, supabaseAnonKey) : null

const tournamentName = ref('')
const matches = ref([])
const rankings = ref([])

const statusMap = ['未开始', '进行中', '已结束']

onMounted(async () => {
  if (useSupabase) {
    await loadFromSupabase()
    subscribeToUpdates()
  } else {
    await loadFromJson()
  }
})

async function loadFromJson() {
  const res = await fetch('/sample_live_share.json')
  const sampleData = await res.json()
  tournamentName.value = sampleData.tournamentName
  matches.value = sampleData.matches.sort((a, b) => a.displayOrder - b.displayOrder)
  rankings.value = sampleData.rankings
}

async function loadFromSupabase() {
  const { data: matchData } = await supabase
    .from('matches')
    .select('*')
    .order('display_order', { ascending: true })
  if (matchData) matches.value = matchData

  const { data: rankingData } = await supabase
    .from('rankings')
    .select('*')
    .order('net_score', { ascending: false })
  if (rankingData) rankings.value = rankingData

  const { data: tournamentData } = await supabase
    .from('tournaments')
    .select('name')
    .single()
  if (tournamentData) tournamentName.value = tournamentData.name
}

function subscribeToUpdates() {
  supabase
    .channel('all-matches')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'matches' }, () => loadFromSupabase())
    .on('postgres_changes', { event: '*', schema: 'public', table: 'rankings' }, () => loadFromSupabase())
    .subscribe()
}

function getStatusText(status) {
  return statusMap[status] || '未知'
}
</script>

<template>
  <div class="container">
    <header>
      <h1>{{ tournamentName || '羽毛球实时比分' }}</h1>
      <p class="subtitle">实时比分 · 排行榜</p>
    </header>

    <section class="matches-section">
      <h2>比赛列表</h2>
      <div class="matches-grid">
        <div
          v-for="match in matches"
          :key="match.displayOrder ?? match.display_order"
          class="match-card"
          :class="'status-' + (match.status ?? match.status)"
        >
          <div class="match-status">{{ getStatusText(match.status ?? match.status) }}</div>
          <div class="match-players">
            <div class="player-row team-a">
              <span class="player-names">{{ match.playerA1Name ?? match.player_a1_name }} / {{ match.playerA2Name ?? match.player_a2_name }}</span>
              <span class="score">{{ match.scoreA ?? match.score_a }}</span>
            </div>
            <div class="vs">VS</div>
            <div class="player-row team-b">
              <span class="player-names">{{ match.playerB1Name ?? match.player_b1_name }} / {{ match.playerB2Name ?? match.player_b2_name }}</span>
              <span class="score">{{ match.scoreB ?? match.score_b }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="rankings-section">
      <h2>排行榜</h2>
      <div class="rankings-table">
        <div class="ranking-header">
          <span class="rank">排名</span>
          <span class="name">选手</span>
          <span class="stat">场次</span>
          <span class="stat">胜场</span>
          <span class="stat">得分</span>
          <span class="stat">失分</span>
          <span class="stat">净胜</span>
        </div>
        <div
          v-for="(player, idx) in rankings"
          :key="player.playerId ?? player.player_id"
          class="ranking-row"
        >
          <span class="rank">{{ idx + 1 }}</span>
          <span class="name">{{ player.playerName ?? player.player_name }}</span>
          <span class="stat">{{ player.matchesPlayed ?? player.matches_played }}</span>
          <span class="stat">{{ player.wins }}</span>
          <span class="stat">{{ player.totalScore ?? player.total_score }}</span>
          <span class="stat">{{ player.totalLost ?? player.total_lost }}</span>
          <span class="stat" :class="(player.netScore ?? player.net_score) >= 0 ? 'positive' : 'negative'">
            {{ (player.netScore ?? player.net_score) >= 0 ? '+' : '' }}{{ player.netScore ?? player.net_score }}
          </span>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.container {
  min-height: 100vh;
  background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
  color: #fff;
  font-family: 'Orbitron', 'Arial Black', sans-serif;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

header {
  text-align: center;
  margin-bottom: 3rem;
}

header h1 {
  font-size: 2.5rem;
  font-weight: 900;
  letter-spacing: 0.1em;
  text-shadow: 0 0 30px rgba(255, 255, 255, 0.3);
}

.subtitle {
  color: #888;
  margin-top: 0.5rem;
  font-size: 0.9rem;
  letter-spacing: 0.3em;
}

.matches-section,
.rankings-section {
  margin-bottom: 3rem;
}

h2 {
  font-size: 1.5rem;
  margin-bottom: 1.5rem;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid rgba(255, 255, 255, 0.1);
  letter-spacing: 0.1em;
}

.matches-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 1.5rem;
}

.match-card {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
  padding: 1.5rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.match-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.status-0 { border-left: 4px solid #666; }
.status-1 { border-left: 4px solid #ffa500; }
.status-2 { border-left: 4px solid #00ff88; }

.match-status {
  font-size: 0.8rem;
  color: #888;
  margin-bottom: 1rem;
  letter-spacing: 0.2em;
}

.match-players {
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
}

.player-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
}

.player-names {
  font-size: 1rem;
  font-weight: 700;
}

.score {
  font-size: 2rem;
  font-weight: 900;
  background: linear-gradient(180deg, #fff, #aaa);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  min-width: 60px;
  text-align: right;
}

.vs {
  text-align: center;
  color: #666;
  font-size: 0.9rem;
  letter-spacing: 0.5em;
}

.rankings-table {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.ranking-header,
.ranking-row {
  display: grid;
  grid-template-columns: 60px 1fr repeat(5, 80px);
  padding: 1rem 1.5rem;
  align-items: center;
  text-align: center;
}

.ranking-header {
  background: rgba(255, 255, 255, 0.08);
  font-size: 0.8rem;
  letter-spacing: 0.1em;
  color: #888;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.ranking-row {
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  transition: background 0.3s ease;
}

.ranking-row:hover {
  background: rgba(255, 255, 255, 0.05);
}

.ranking-row:last-child {
  border-bottom: none;
}

.rank {
  font-weight: 900;
  font-size: 1.2rem;
}

.name {
  text-align: left;
  font-weight: 700;
}

.stat {
  font-size: 0.9rem;
}

.positive { color: #00ff88; }
.negative { color: #ff4444; }
</style>
