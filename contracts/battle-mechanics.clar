;; Digital Collectible Card Game - Battle Mechanics Contract
;; Manages turn-based battles between players using their card collections
;; Implements deterministic combat resolution and player ranking systems

;; ===== CONSTANTS =====
;; Error constants for comprehensive error handling
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-BATTLE-NOT-ACTIVE (err u407))
(define-constant ERR-ALREADY-IN-BATTLE (err u408))
(define-constant ERR-INSUFFICIENT-MANA (err u409))
(define-constant ERR-CARD-ALREADY-PLAYED (err u410))
(define-constant ERR-NOT-PLAYER-TURN (err u411))
(define-constant ERR-BATTLE-ALREADY-FINISHED (err u412))
(define-constant ERR-INVALID-CARD-DATA (err u413))

;; Battle configuration constants
(define-constant MAX-CARDS-PER-BATTLE u5)
(define-constant INITIAL-PLAYER-HEALTH u30)
(define-constant INITIAL-MANA u3)
(define-constant MAX-MANA u10)
(define-constant MANA-PER-TURN u1)
(define-constant BATTLE-TIMEOUT-BLOCKS u1000)

;; Battle states for state management
(define-constant BATTLE-STATE-WAITING u1)
(define-constant BATTLE-STATE-ACTIVE u2)
(define-constant BATTLE-STATE-FINISHED u3)
(define-constant BATTLE-STATE-CANCELLED u4)

;; Victory conditions and rewards
(define-constant VICTORY-POINTS-WIN u100)
(define-constant VICTORY-POINTS-LOSE u25)
(define-constant VICTORY-POINTS-DRAW u50)

;; Player turn indicators
(define-constant PLAYER-ONE u1)
(define-constant PLAYER-TWO u2)

;; ===== DATA VARIABLES =====
;; Track the next available battle ID
(define-data-var next-battle-id uint u1)

;; Track total number of battles completed
(define-data-var total-battles-completed uint u0)

;; Global battle settings that can be adjusted
(define-data-var battles-enabled bool true)
(define-data-var min-bet-amount uint u0)

;; ===== DATA MAPS =====
;; Store comprehensive battle information
(define-map battles uint {
    player1: principal,
    player2: (optional principal),
    state: uint,
    current-turn: uint,
    turn-count: uint,
    player1-health: uint,
    player2-health: uint,
    player1-mana: uint,
    player2-mana: uint,
    winner: (optional principal),
    created-at: uint,
    finished-at: (optional uint),
    bet-amount: uint
})

;; Track cards played in each battle with their stats
(define-map battle-cards { battle-id: uint, player: principal, card-slot: uint } {
    owner: principal,
    token-id: uint,
    attack: uint,
    defense: uint,
    health: uint,
    current-health: uint,
    mana-cost: uint,
    rarity: uint,
    played-turn: uint,
    is-alive: bool
})

;; Store player statistics and rankings
(define-map player-stats principal {
    total-battles: uint,
    wins: uint,
    losses: uint,
    draws: uint,
    victory-points: uint,
    cards-played: uint,
    damage-dealt: uint,
    damage-taken: uint,
    last-battle: (optional uint)
})

;; Track active battles for each player (prevent multiple concurrent battles)
(define-map active-player-battles principal uint)

;; Store battle history for analysis and replay
(define-map battle-actions { battle-id: uint, turn: uint, action-id: uint } {
    player: principal,
    action-type: (string-ascii 32),
    card-token-id: (optional uint),
    target-slot: (optional uint),
    damage-dealt: uint,
    block-height: uint
})

;; ===== PUBLIC FUNCTIONS =====

;; Create a new battle lobby and wait for opponent
(define-public (create-battle (bet-amount uint))
    (let ((battle-id (var-get next-battle-id))
          (creator tx-sender))
        ;; Validate battle creation conditions
        (asserts! (var-get battles-enabled) ERR-UNAUTHORIZED)
        (asserts! (>= bet-amount (var-get min-bet-amount)) ERR-INVALID-PARAMETERS)
        (asserts! (is-none (map-get? active-player-battles creator)) ERR-ALREADY-IN-BATTLE)
        
        ;; Create new battle record
        (map-set battles battle-id {
            player1: creator,
            player2: none,
            state: BATTLE-STATE-WAITING,
            current-turn: PLAYER-ONE,
            turn-count: u1,
            player1-health: INITIAL-PLAYER-HEALTH,
            player2-health: INITIAL-PLAYER-HEALTH,
            player1-mana: INITIAL-MANA,
            player2-mana: INITIAL-MANA,
            winner: none,
            created-at: block-height,
            finished-at: none,
            bet-amount: bet-amount
        })
        
        ;; Mark player as having an active battle
        (map-set active-player-battles creator battle-id)
        
        ;; Update battle counter
        (var-set next-battle-id (+ battle-id u1))
        
        (ok battle-id)))

;; Join an existing battle lobby
(define-public (join-battle (battle-id uint))
    (let ((battle-data (unwrap! (map-get? battles battle-id) ERR-NOT-FOUND))
          (joiner tx-sender))
        ;; Validate join conditions
        (asserts! (is-none (get player2 battle-data)) ERR-ALREADY-IN-BATTLE)
        (asserts! (not (is-eq joiner (get player1 battle-data))) ERR-INVALID-PARAMETERS)
        (asserts! (is-eq (get state battle-data) BATTLE-STATE-WAITING) ERR-BATTLE-NOT-ACTIVE)
        (asserts! (is-none (map-get? active-player-battles joiner)) ERR-ALREADY-IN-BATTLE)
        
        ;; Update battle with second player and activate
        (map-set battles battle-id (merge battle-data {
            player2: (some joiner),
            state: BATTLE-STATE-ACTIVE
        }))
        
        ;; Mark both players as having active battles
        (map-set active-player-battles joiner battle-id)
        
        (ok true)))

;; Play a card in battle with specified stats
;; Note: Card stats are passed as parameters instead of cross-contract calls
(define-public (play-card (battle-id uint) 
                         (card-owner principal)
                         (token-id uint)
                         (attack uint)
                         (defense uint)
                         (health uint)
                         (mana-cost uint)
                         (rarity uint)
                         (card-slot uint))
    (let ((battle-data (unwrap! (map-get? battles battle-id) ERR-NOT-FOUND))
          (player tx-sender)
          (current-player-num (if (is-eq player (get player1 battle-data)) PLAYER-ONE PLAYER-TWO))
          (player-mana (if (is-eq current-player-num PLAYER-ONE) 
                          (get player1-mana battle-data) 
                          (get player2-mana battle-data))))
        
        ;; Validate play conditions
        (asserts! (is-eq (get state battle-data) BATTLE-STATE-ACTIVE) ERR-BATTLE-NOT-ACTIVE)
        (asserts! (is-eq (get current-turn battle-data) current-player-num) ERR-NOT-PLAYER-TURN)
        (asserts! (<= card-slot MAX-CARDS-PER-BATTLE) ERR-INVALID-PARAMETERS)
        (asserts! (<= mana-cost player-mana) ERR-INSUFFICIENT-MANA)
        (asserts! (is-eq card-owner player) ERR-UNAUTHORIZED)
        (asserts! (> attack u0) ERR-INVALID-CARD-DATA)
        (asserts! (> health u0) ERR-INVALID-CARD-DATA)
        (asserts! (is-none (map-get? battle-cards { battle-id: battle-id, player: player, card-slot: card-slot })) 
                 ERR-CARD-ALREADY-PLAYED)
        
        ;; Place card in battle slot
        (map-set battle-cards { battle-id: battle-id, player: player, card-slot: card-slot } {
            owner: card-owner,
            token-id: token-id,
            attack: attack,
            defense: defense,
            health: health,
            current-health: health,
            mana-cost: mana-cost,
            rarity: rarity,
            played-turn: (get turn-count battle-data),
            is-alive: true
        })
        
        ;; Deduct mana cost
        (if (is-eq current-player-num PLAYER-ONE)
            (map-set battles battle-id (merge battle-data {
                player1-mana: (- (get player1-mana battle-data) mana-cost)
            }))
            (map-set battles battle-id (merge battle-data {
                player2-mana: (- (get player2-mana battle-data) mana-cost)
            })))
        
        (ok true)))

;; End current turn and switch to opponent
(define-public (end-turn (battle-id uint))
    (let ((battle-data (unwrap! (map-get? battles battle-id) ERR-NOT-FOUND))
          (player tx-sender)
          (current-player-num (if (is-eq player (get player1 battle-data)) PLAYER-ONE PLAYER-TWO)))
        
        ;; Validate turn ending conditions
        (asserts! (is-eq (get state battle-data) BATTLE-STATE-ACTIVE) ERR-BATTLE-NOT-ACTIVE)
        (asserts! (is-eq (get current-turn battle-data) current-player-num) ERR-NOT-PLAYER-TURN)
        
        ;; Switch turn and increment counters
        (let ((next-turn (if (is-eq current-player-num PLAYER-ONE) PLAYER-TWO PLAYER-ONE))
              (next-turn-count (+ (get turn-count battle-data) u1)))
            
            ;; Add mana for new turn (up to maximum)
            (let ((new-p1-mana (if (> (+ (get player1-mana battle-data) MANA-PER-TURN) MAX-MANA)
                                  MAX-MANA
                                  (+ (get player1-mana battle-data) MANA-PER-TURN)))
                  (new-p2-mana (if (> (+ (get player2-mana battle-data) MANA-PER-TURN) MAX-MANA)
                                  MAX-MANA
                                  (+ (get player2-mana battle-data) MANA-PER-TURN))))
                
                (map-set battles battle-id (merge battle-data {
                    current-turn: next-turn,
                    turn-count: next-turn-count,
                    player1-mana: new-p1-mana,
                    player2-mana: new-p2-mana
                }))
                
                (ok true)))))

;; Execute combat between cards using deterministic rules
(define-public (execute-combat (battle-id uint) 
                              (attacker-slot uint) 
                              (defender-slot uint))
    (let ((battle-data (unwrap! (map-get? battles battle-id) ERR-NOT-FOUND))
          (player tx-sender)
          (opponent (if (is-eq player (get player1 battle-data)) 
                       (unwrap! (get player2 battle-data) ERR-NOT-FOUND)
                       (get player1 battle-data))))
        
        ;; Validate combat conditions
        (asserts! (is-eq (get state battle-data) BATTLE-STATE-ACTIVE) ERR-BATTLE-NOT-ACTIVE)
        
        ;; Get attacker and defender cards
        (let ((attacker-card (unwrap! (map-get? battle-cards { battle-id: battle-id, player: player, card-slot: attacker-slot }) ERR-NOT-FOUND))
              (defender-card (unwrap! (map-get? battle-cards { battle-id: battle-id, player: opponent, card-slot: defender-slot }) ERR-NOT-FOUND)))
            
            (asserts! (get is-alive attacker-card) ERR-INVALID-PARAMETERS)
            (asserts! (get is-alive defender-card) ERR-INVALID-PARAMETERS)
            
            ;; Calculate damage using deterministic pseudo-random factor
            (let ((base-damage (get attack attacker-card))
                  (defense-value (get defense defender-card))
                  (random-factor (+ (mod (+ block-height battle-id) u3) u1)) ;; 1-3 multiplier
                  (final-damage (if (> (- (* base-damage random-factor) defense-value) u1)
                                   (- (* base-damage random-factor) defense-value)
                                   u1)))
                
                ;; Apply damage to defender
                (let ((new-health (if (<= (get current-health defender-card) final-damage)
                                    u0
                                    (- (get current-health defender-card) final-damage))))
                    
                    ;; Update defender card health
                    (map-set battle-cards { battle-id: battle-id, player: opponent, card-slot: defender-slot }
                        (merge defender-card {
                            current-health: new-health,
                            is-alive: (> new-health u0)
                        }))
                    
                    (ok final-damage))))))

;; ===== READ-ONLY FUNCTIONS =====

;; Get battle information
(define-read-only (get-battle (battle-id uint))
    (map-get? battles battle-id))

;; Get card information in a specific battle slot
(define-read-only (get-battle-card (battle-id uint) (player principal) (card-slot uint))
    (map-get? battle-cards { battle-id: battle-id, player: player, card-slot: card-slot }))

;; Get player statistics
(define-read-only (get-player-stats (player principal))
    (default-to {
        total-battles: u0,
        wins: u0,
        losses: u0,
        draws: u0,
        victory-points: u0,
        cards-played: u0,
        damage-dealt: u0,
        damage-taken: u0,
        last-battle: none
    } (map-get? player-stats player)))

;; Get active battle for a player
(define-read-only (get-active-battle (player principal))
    (map-get? active-player-battles player))

;; Get total battles completed globally
(define-read-only (get-total-battles)
    (var-get total-battles-completed))

;; Check if battles are currently enabled
(define-read-only (are-battles-enabled)
    (var-get battles-enabled))

;; Calculate win rate for a player
(define-read-only (get-win-rate (player principal))
    (let ((stats (get-player-stats player)))
        (if (> (get total-battles stats) u0)
            (some (/ (* (get wins stats) u100) (get total-battles stats)))
            none)))

;; Get next available battle ID
(define-read-only (get-next-battle-id)
    (var-get next-battle-id))
