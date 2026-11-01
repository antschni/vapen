import { tv, type VariantProps } from "tailwind-variants";

export const buttonVariants = tv({
  base: "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full text-sm font-medium transition-[color,background-color,border-color,box-shadow,transform] outline-none select-none focus-visible:ring-[3px] focus-visible:ring-ring/35 active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  variants: {
    variant: {
      default:
        "bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgb(255_255_255/0.15),0_1px_2px_0_rgb(0_0_0/0.1)] hover:bg-primary/90",
      destructive:
        "bg-destructive text-destructive-foreground shadow-[inset_0_1px_0_0_rgb(255_255_255/0.15)] hover:bg-destructive/90 focus-visible:ring-destructive/30",
      "destructive-ghost":
        "text-destructive hover:bg-destructive/10 focus-visible:ring-destructive/30",
      outline:
        "bg-card text-foreground shadow-card hover:bg-accent",
      secondary:
        "bg-secondary text-secondary-foreground hover:bg-accent",
      ghost: "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
      link: "h-auto px-0 text-primary underline-offset-4 hover:underline active:scale-100",
    },
    size: {
      default: "h-10 px-5",
      sm: "h-8 gap-1.5 px-3.5 text-[13px]",
      lg: "h-11 px-6 text-[15px]",
      icon: "size-10",
      "icon-sm": "size-8",
    },
  },
  defaultVariants: {
    variant: "default",
    size: "default",
  },
});

export type ButtonVariants = VariantProps<typeof buttonVariants>;
