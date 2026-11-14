// 伴随面板 Feature（判据正源: references/page-splitting.md——画布/IDE 伴随面板型封闭交互单元；
// 选中项与校验数据由入口下发）
type PanelItem = { title: string; description: string };
type Issue = { target: string; text: string };

type Props = {
  selected?: PanelItem;
  issues: Issue[];
};

export default function InsightPanel({ selected, issues }: Props) {
  return (
    <aside className="jjui-editor-panel" data-jjui-region="p-04.panel">
      <div className="jjui-section__title">{selected?.title}</div>
      <p className="jjui-section__description">{selected?.description}</p>
      <div className="jjui-section__subtitle">校验</div>
      {issues.map((issue) => (
        <p key={issue.text} className="jjui-section__description">{issue.text}</p>
      ))}
      <div className="jjui-section__subtitle">提示</div>
      <p className="jjui-section__description">修改后需通过校验才可发布。</p>
    </aside>
  );
}
