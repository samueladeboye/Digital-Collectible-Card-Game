;; Digital Collectible Card Game - Card NFT Contract
;; Manages the creation, ownership, and transfer of unique collectible cards
;; Each card has unique stats and metadata making them valuable NFTs

;; ===== CONSTANTS =====
;; Error constants for better error handling and debugging
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-TOKEN-ID (err u403))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-MAX-SUPPLY-REACHED (err u405))
(define-constant ERR-CARD-NOT-TRANSFERABLE (err u406))

;; Maximum number of cards that can ever be minted
(define-constant MAX-SUPPLY u10000)

;; Card rarity levels - affects card value and battle effectiveness
(define-constant RARITY-COMMON u1)
(define-constant RARITY-UNCOMMON u2)
(define-constant RARITY-RARE u3)
(define-constant RARITY-EPIC u4)
(define-constant RARITY-LEGENDARY u5)

;; Contract deployer is the initial administrator
(define-constant CONTRACT-OWNER tx-sender)

;; ===== DATA VARIABLES =====
;; Track the total number of cards minted so far
(define-data-var total-supply uint u0)

;; Track the next available token ID for minting new cards
(define-data-var next-token-id uint u1)

;; Flag to pause/unpause minting in case of emergencies
(define-data-var minting-enabled bool true)

;; Base URI for card metadata - can be updated by owner
(define-data-var base-token-uri (string-ascii 256) "https://api.digital-collectible-card-game.com/metadata/")

;; ===== DATA MAPS =====
;; Track who owns each card by token ID
(define-map token-owners uint principal)

;; Track how many cards each principal owns
(define-map owner-balances principal uint)

;; Store comprehensive metadata for each card including battle stats
(define-map card-metadata uint {
    name: (string-ascii 64),
    description: (string-ascii 256),
    image: (string-ascii 256),
    attack: uint,
    defense: uint,
    health: uint,
    mana-cost: uint,
    rarity: uint,
    card-type: (string-ascii 32),
    special-ability: (string-ascii 128),
    created-at: uint
})

;; Track approved operators for each token (for marketplace functionality)
(define-map token-approvals uint principal)

;; Track operators approved for all tokens of an owner
(define-map operator-approvals { owner: principal, operator: principal } bool)

;; Store card collection names/themes for better organization
(define-map card-collections (string-ascii 64) {
    creator: principal,
    total-cards: uint,
    base-stats: { min-attack: uint, max-attack: uint, min-defense: uint, max-defense: uint }
})

;; ===== PUBLIC FUNCTIONS =====

;; Mint a new card with specified metadata and stats
;; Only the contract owner can mint cards initially
(define-public (mint-card (to principal) 
                         (name (string-ascii 64))
                         (description (string-ascii 256))
                         (image (string-ascii 256))
                         (attack uint)
                         (defense uint)
                         (health uint)
                         (mana-cost uint)
                         (rarity uint)
                         (card-type (string-ascii 32))
                         (special-ability (string-ascii 128)))
    (let ((token-id (var-get next-token-id))
          (current-supply (var-get total-supply)))
        ;; Validate minting conditions
        (asserts! (var-get minting-enabled) ERR-UNAUTHORIZED)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (< current-supply MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
        (asserts! (<= rarity RARITY-LEGENDARY) ERR-INVALID-PARAMETERS)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMETERS)
        (asserts! (and (> attack u0) (<= attack u1000)) ERR-INVALID-PARAMETERS)
        (asserts! (and (> defense u0) (<= defense u1000)) ERR-INVALID-PARAMETERS)
        (asserts! (and (> health u0) (<= health u2000)) ERR-INVALID-PARAMETERS)
        (asserts! (<= mana-cost u20) ERR-INVALID-PARAMETERS)
        
        ;; Create the card metadata record
        (map-set card-metadata token-id {
            name: name,
            description: description,
            image: image,
            attack: attack,
            defense: defense,
            health: health,
            mana-cost: mana-cost,
            rarity: rarity,
            card-type: card-type,
            special-ability: special-ability,
            created-at: block-height
        })
        
        ;; Set ownership and update balances
        (map-set token-owners token-id to)
        (map-set owner-balances to (+ (get-balance to) u1))
        
        ;; Update contract state
        (var-set total-supply (+ current-supply u1))
        (var-set next-token-id (+ token-id u1))
        
        ;; Return success with the minted token ID
        (ok token-id)))

;; Transfer a card from one owner to another
;; Includes authorization checks and balance updates
(define-public (transfer (token-id uint) (from principal) (to principal))
    (let ((owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
        ;; Validate transfer conditions
        (asserts! (is-eq owner from) ERR-UNAUTHORIZED)
        (asserts! (or (is-eq tx-sender from)
                     (is-eq tx-sender (default-to from (map-get? token-approvals token-id)))
                     (default-to false (map-get? operator-approvals { owner: from, operator: tx-sender })))
                 ERR-UNAUTHORIZED)
        (asserts! (not (is-eq from to)) ERR-INVALID-PARAMETERS)
        
        ;; Update ownership records
        (map-set token-owners token-id to)
        
        ;; Update balance counters
        (map-set owner-balances from (- (get-balance from) u1))
        (map-set owner-balances to (+ (get-balance to) u1))
        
        ;; Clear any existing approval for this token
        (map-delete token-approvals token-id)
        
        (ok true)))

;; Approve another principal to transfer a specific token
;; Useful for marketplace and trading functionality
(define-public (approve (token-id uint) (approved principal))
    (let ((owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND)))
        (asserts! (or (is-eq tx-sender owner)
                     (default-to false (map-get? operator-approvals { owner: owner, operator: tx-sender })))
                 ERR-UNAUTHORIZED)
        (map-set token-approvals token-id approved)
        (ok true)))

;; Set or unset approval for all tokens owned by the caller
;; Enables marketplace contracts to manage all user's cards
(define-public (set-approval-for-all (operator principal) (approved bool))
    (ok (map-set operator-approvals { owner: tx-sender, operator: operator } approved)))

;; Admin function to pause/unpause minting
(define-public (set-minting-enabled (enabled bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set minting-enabled enabled)
        (ok true)))

;; Admin function to update the base URI for metadata
(define-public (set-base-uri (new-uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set base-token-uri new-uri)
        (ok true)))

;; ===== READ-ONLY FUNCTIONS =====

;; Get the owner of a specific token
(define-read-only (get-owner (token-id uint))
    (map-get? token-owners token-id))

;; Get the number of cards owned by a specific principal
(define-read-only (get-balance (owner principal))
    (default-to u0 (map-get? owner-balances owner)))

;; Get comprehensive metadata for a specific card
(define-read-only (get-card-metadata (token-id uint))
    (map-get? card-metadata token-id))

;; Get basic card stats for battle calculations
(define-read-only (get-card-stats (token-id uint))
    (match (map-get? card-metadata token-id)
        card-data (some {
            attack: (get attack card-data),
            defense: (get defense card-data),
            health: (get health card-data),
            mana-cost: (get mana-cost card-data),
            rarity: (get rarity card-data)
        })
        none))

;; Get the approved principal for a specific token
(define-read-only (get-approved (token-id uint))
    (map-get? token-approvals token-id))

;; Check if an operator is approved for all tokens of an owner
(define-read-only (is-approved-for-all (owner principal) (operator principal))
    (default-to false (map-get? operator-approvals { owner: owner, operator: operator })))

;; Get the total number of cards minted
(define-read-only (get-total-supply)
    (var-get total-supply))

;; Get the maximum supply limit
(define-read-only (get-max-supply)
    MAX-SUPPLY)

;; Check if minting is currently enabled
(define-read-only (is-minting-enabled)
    (var-get minting-enabled))

;; Get the current base URI for metadata
(define-read-only (get-base-uri)
    (var-get base-token-uri))

;; Get the contract owner address
(define-read-only (get-contract-owner)
    CONTRACT-OWNER)

;; Calculate card power rating based on stats and rarity
(define-read-only (get-card-power (token-id uint))
    (match (map-get? card-metadata token-id)
        card-data (let ((base-power (+ (+ (get attack card-data) (get defense card-data)) (get health card-data)))
                       (rarity-multiplier (get rarity card-data)))
                     (some (* base-power rarity-multiplier)))
        none))

;; Check if a card exists (has been minted)
(define-read-only (card-exists (token-id uint))
    (is-some (map-get? token-owners token-id)))
