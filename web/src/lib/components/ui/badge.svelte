<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';
	import { tv, type VariantProps } from 'tailwind-variants';

	const badgeVariants = tv({
		base: 'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] leading-4 font-medium whitespace-nowrap [&_svg]:size-3',
		variants: {
			variant: {
				default: 'bg-primary/10 text-primary dark:bg-primary/15',
				solid: 'bg-primary text-primary-foreground',
				secondary: 'bg-muted text-muted-foreground',
				outline: 'border border-border text-muted-foreground',
				success: 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300',
				warning: 'bg-amber-500/10 text-amber-700 dark:text-amber-300',
				destructive: 'bg-destructive/10 text-destructive'
			}
		},
		defaultVariants: {
			variant: 'default'
		}
	});

	type Variants = VariantProps<typeof badgeVariants>;

	type Props = HTMLAttributes<HTMLSpanElement> & {
		variant?: Variants['variant'];
		class?: string;
		children?: Snippet;
	};

	let { class: className, variant = 'default', children, ...rest }: Props = $props();
</script>

<span class={cn(badgeVariants({ variant }), className)} {...rest}>
	{@render children?.()}
</span>
