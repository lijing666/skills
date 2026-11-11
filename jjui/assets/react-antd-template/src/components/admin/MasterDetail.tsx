import type { ReactNode } from "react";

type MasterDetailProps = {
  aside: ReactNode;
  children: ReactNode;
  className?: string;
  /** 门牌放容器内部顶部（判据正源: composition-layer.md 主从布局段——外层不得再包 SectionCard 或带题卡） */
  title?: string;
  description?: string;
};

export default function MasterDetail({ aside, children, className, title, description }: MasterDetailProps) {
  const classes = ["jjui-master", className].filter(Boolean).join(" ");

  return (
    <div className={classes}>
      {title ? (
        <header className="jjui-master__head">
          <h2 className="jjui-master__title">{title}</h2>
          {description ? <p className="jjui-master__description">{description}</p> : null}
        </header>
      ) : null}
      <div className="jjui-master__body">
        <aside className="jjui-master__aside">{aside}</aside>
        <main className="jjui-master__main">{children}</main>
      </div>
    </div>
  );
}
