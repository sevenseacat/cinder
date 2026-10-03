const scrollContainer = (element) => {
  for (let candidate = element; candidate; candidate = candidate.parentElement) {
    const { overflowY } = window.getComputedStyle(candidate);

    if (/(auto|scroll|overlay)/.test(overflowY) && candidate.scrollHeight > candidate.clientHeight) {
      return candidate;
    }
  }

  return document.scrollingElement;
};

const viewportBounds = (scroller) => {
  if (scroller === document.scrollingElement) {
    return { top: 0, bottom: window.innerHeight };
  }

  const bounds = scroller.getBoundingClientRect();
  return { top: bounds.top, bottom: bounds.bottom };
};

const CinderInfiniteStream = {
  mounted() {
    this.appliedSelectionState = null;
    this.syncSelection();
  },

  beforeUpdate() {
    const scroller = scrollContainer(this.el);
    const viewport = viewportBounds(scroller);

    this.viewportAnchors = Array.from(this.el.querySelectorAll("[data-item-id]"))
      .map((item) => {
        const bounds = item.getBoundingClientRect();

        return {
          id: item.dataset.itemId,
          offset: bounds.top - viewport.top,
          visible: bounds.bottom > viewport.top && bounds.top < viewport.bottom,
        };
      })
      .filter(({ visible }) => visible);
    this.viewportScroller = scroller;
  },

  updated() {
    this.syncSelection();
    cancelAnimationFrame(this.viewportAnchorFrame);
    this.viewportAnchorFrame = requestAnimationFrame(() => this.restoreViewportAnchor());
  },

  destroyed() {
    cancelAnimationFrame(this.viewportAnchorFrame);
  },

  syncSelection() {
    const signature = `${this.el.dataset.selectedIds || "[]"}\n${this.el.dataset.selectedClasses || "[]"}`;
    if (signature === this.appliedSelectionState) return;

    this.appliedSelectionState = signature;
    const selected = new Set(JSON.parse(this.el.dataset.selectedIds || "[]"));
    const selectedClasses = JSON.parse(this.el.dataset.selectedClasses || "[]");

    this.el.querySelectorAll("[data-item-id]").forEach((item) => {
      const isSelected = selected.has(item.dataset.itemId);
      const checkbox = item.querySelector("[data-cinder-selection-checkbox]");
      if (checkbox) checkbox.checked = isSelected;
      selectedClasses.forEach((name) => item.classList.toggle(name, isSelected));
    });
  },

  restoreViewportAnchor() {
    const anchors = this.viewportAnchors;
    const scroller = this.viewportScroller;
    this.viewportAnchors = null;
    this.viewportScroller = null;

    if (!anchors?.length || !scroller?.isConnected) return;

    const itemsById = new Map(
      Array.from(this.el.querySelectorAll("[data-item-id]"), (item) => [item.dataset.itemId, item]),
    );
    const anchor = anchors
      .map((position) => ({ position, item: itemsById.get(position.id) }))
      .find(({ item }) => item);

    if (!anchor) return;

    const viewport = viewportBounds(scroller);
    const currentOffset = anchor.item.getBoundingClientRect().top - viewport.top;
    const adjustment = currentOffset - anchor.position.offset;

    if (Math.abs(adjustment) > 0.5) scroller.scrollTop += adjustment;
  },

};

const CinderInfiniteSentinel = {
  mounted() {
    this.triggered = false;
    this.observeAheadOfViewport();

    this.handleResize = () => this.observeAheadOfViewport();
    window.addEventListener("resize", this.handleResize, { passive: true });
  },

  destroyed() {
    this.observer?.disconnect();
    window.removeEventListener("resize", this.handleResize);
  },

  reconnected() {
    if (!this.triggered) this.observeAheadOfViewport();
  },

  observeAheadOfViewport() {
    if (this.triggered) return;

    this.observer?.disconnect();

    const stream = this.el.closest("[data-cinder-infinite-root]");
    const scroller = scrollContainer(stream || this.el);
    const viewport = viewportBounds(scroller);
    const overscan = Math.max(Number.parseInt(this.el.dataset.infiniteOverscan || "1", 10), 0);

    // Overscan already controls how many extra batches Cinder keeps ready. Use
    // the same setting to move the sentinel trigger farther ahead without
    // introducing a second prefetch configuration.
    const prefetchDistance = Math.max(viewport.bottom - viewport.top, 400) * (1 + overscan);

    this.observer = new IntersectionObserver(
      async ([entry]) => {
        if (!entry?.isIntersecting || this.triggered) return;

        this.triggered = true;
        this.observer.disconnect();

        try {
          const results = await this.pushEventTo(this.el, "load_more", {});
          const failure = results.find(({ status }) => status === "rejected");

          if (results.length === 0) {
            throw new Error("no LiveView target accepted the load_more push");
          }

          if (failure) throw failure.reason;
        } catch (error) {
          this.triggered = false;
          console.error("Cinder infinite-scroll load_more push failed", error);
        }
      },
      {
        root: scroller === document.scrollingElement ? null : scroller,
        rootMargin: `0px 0px ${prefetchDistance}px 0px`,
        threshold: 0,
      },
    );

    this.observer.observe(this.el);
  },
};

export const hooks = { CinderInfiniteSentinel, CinderInfiniteStream };
