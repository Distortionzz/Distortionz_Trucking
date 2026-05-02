(function () {
    const panel        = document.getElementById('truckingPanel');
    const timer        = document.getElementById('contractTimer');
    const stagePill    = document.getElementById('stagePill');
    const stageLabel   = document.getElementById('stageLabel');
    const stageHint    = document.getElementById('stageHint');
    const cargoName    = document.getElementById('cargoName');
    const cargoIcon    = document.getElementById('cargoIcon');
    const dropoffName  = document.getElementById('dropoffName');
    const payoutValue  = document.getElementById('payoutValue');

    const manifestId      = document.getElementById('manifestId');
    const containerNumber = document.getElementById('containerNumber');
    const grossWeight     = document.getElementById('grossWeight');
    const shipperName     = document.getElementById('shipperName');
    const consigneeName   = document.getElementById('consigneeName');

    const STAGE_MAP = {
        pickup:    { label: 'PICKUP',    hint: 'Back the truck into the trailer' },
        driving:   { label: 'IN TRANSIT', hint: 'Drive carefully to the drop-off' },
        delivered: { label: 'DELIVERED',  hint: 'Run complete' },
    };

    function formatTime(seconds) {
        if (seconds < 0) seconds = 0;
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }

    function applyStage(stage) {
        const info = STAGE_MAP[stage] || STAGE_MAP.pickup;
        stagePill.classList.remove('pickup', 'driving', 'delivered');
        stagePill.classList.add(stage in STAGE_MAP ? stage : 'pickup');
        stageLabel.textContent = info.label;
        stageHint.textContent = info.hint;
    }

    function applyTimer(secondsLeft) {
        timer.textContent = formatTime(secondsLeft);
        timer.classList.remove('warning', 'critical');
        if (secondsLeft <= 60)       timer.classList.add('critical');
        else if (secondsLeft <= 180) timer.classList.add('warning');
    }

    function applyData(data) {
        if (data.cargo) {
            cargoName.innerHTML = '';
            if (data.cargoIcon) {
                const span = document.createElement('span');
                span.id = 'cargoIcon';
                span.textContent = data.cargoIcon + ' ';
                cargoName.appendChild(span);
            }
            cargoName.appendChild(document.createTextNode(data.cargo));
        }
        if (data.dropoff) dropoffName.textContent = data.dropoff;
        if (typeof data.payout === 'number') {
            payoutValue.textContent = `$${data.payout.toLocaleString()}`;
        }

        // Manifest fields
        if (data.manifestId)   manifestId.textContent      = data.manifestId;
        if (data.container)    containerNumber.textContent = data.container;
        if (data.weight)       grossWeight.textContent     = data.weight;
        if (data.shipper)      shipperName.textContent     = data.shipper;
        if (data.consignee)    consigneeName.textContent   = data.consignee;
    }

    window.addEventListener('message', function (event) {
        const data = event.data || {};
        const action = data.action;

        if (action === 'show') {
            panel.classList.remove('hidden');
            applyStage(data.stage || 'pickup');
            applyTimer(typeof data.secondsLeft === 'number' ? data.secondsLeft : 0);
            applyData(data);
        }

        if (action === 'update') {
            if (data.stage) applyStage(data.stage);
            if (typeof data.secondsLeft === 'number') applyTimer(data.secondsLeft);
            applyData(data);
        }

        if (action === 'hide') {
            panel.classList.add('hidden');
        }
    });
})();
